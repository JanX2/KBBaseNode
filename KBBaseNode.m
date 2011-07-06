//
//  KBBaseNode.m
//  --------
//
//  Keith Blount 2005
//  Jan Weiß 2010-2011
//

#import "KBBaseNode.h"
#import "NSArray_Extensions.h"

NSString * const KBChildrenKey = @"children";
NSString * const KBIsLeafKey = @"isLeaf";

NSArray * mutableKeysArray; // Class global cache for mutableKeys

NSString *KBDescriptionForObject(id object, id locale, NSUInteger indentLevel)
{
	NSString *descriptionString;
	BOOL addQuotes = NO;
	
    if ([object isKindOfClass:[NSString class]])
        descriptionString = object;
    else if ([object respondsToSelector:@selector(descriptionWithLocale:indent:)])
        return [(id)object descriptionWithLocale:locale indent:indentLevel];
    else  if ([object respondsToSelector:@selector(descriptionWithLocale:)])
        return [(id)object descriptionWithLocale:locale];
    else
        descriptionString = [object description];
	
	NSRange range = [descriptionString rangeOfString:@" "];
	if (range.location != NSNotFound)
		addQuotes = YES;

	if (addQuotes)
		return [NSString stringWithFormat:@"\"%@\"", descriptionString];
	else
        return descriptionString;
	
}

@implementation KBBaseNode

@synthesize describableKeys;

/*************************** Init/Dealloc ***************************/

#pragma mark -
#pragma mark Init/Dealloc

- (id)init
{
	if (self = [super init])
	{
		[self setTitle:@"Untitled"];
		[self setProperties:[NSDictionary dictionary]];
		[self setChildren:[NSMutableArray array]];
		[self setLeaf:NO];							// Container by default
	}
	return self;
}

- (id)initLeaf
{
	if (self = [self init])
	{
		[self setLeaf:YES];
	}
	return self;
}

- (void)dealloc
{
	[title release];
	[properties release];
	[children release];
	
	[super dealloc];
}


- (NSString *)description
{
	return [self descriptionWithLocale:nil indent:0 describeChildren:YES];
}

- (NSString *)descriptionWithChildren:(BOOL)describeChildren;
{
	return [self descriptionWithLocale:nil indent:0 describeChildren:describeChildren];
}

- (NSString *)descriptionWithLocale:(id)locale;
{
	return [self descriptionWithLocale:locale indent:0 describeChildren:YES];
}

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level;
{
	return [self descriptionWithLocale:locale indent:level describeChildren:YES];
}

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level describeChildren:(BOOL)describeChildren;
{
	NSMutableString *nodeDescription = [[NSMutableString alloc] init];
	
	NSUInteger indentationDepth = (level+1) * 4;
	NSUInteger indentationDepth2 = (level+2) * 4;
	
	NSString *indentation = [@"" stringByPaddingToLength:indentationDepth withString: @" " startingAtIndex:0];
	NSString *indentation2 = [@"" stringByPaddingToLength:indentationDepth2 withString: @" " startingAtIndex:0];
	
	if ([self describableKeys] == nil) {
#if REMOVE_REDUNDANT_LEAF_KEY
		NSMutableArray *newDescribableKeys = [[[self mutableKeys] mutableCopy] autorelease];
		[newDescribableKeys removeObject:KBIsLeafKey];
		[self setDescribableKeys:newDescribableKeys];
#else
		[self setDescribableKeys:[self mutableKeys]];
#endif
	}
	
	for (NSString *key in [self describableKeys])
	{
		
		if ([key isEqualToString:KBChildrenKey])
		{
			if (describeChildren && !isLeaf)
			{
				[nodeDescription appendFormat:@"%@%@ = (\n", indentation, KBChildrenKey];
				id lastChild = [self.children lastObject];
				for (id child in self.children) {
					[nodeDescription appendFormat:
					 @"%1$@{\n%2$@\n%1$@}%3$@\n", 
					 indentation2, 
					 KBDescriptionForObject(child, nil, level+2),
					 (child == lastChild) ? @"" : @"," ];
				}
				[nodeDescription appendFormat:@"%@)\n", indentation];
			}
		}
		else if ([self valueForKey:key]) {
			
			NSString *thisDescription = KBDescriptionForObject([self valueForKey:key], nil, level+1);
			
			BOOL isSingleLine;
			NSRange range = [thisDescription rangeOfString:@"\n"];
			isSingleLine = (range.location == NSNotFound);
			
			[nodeDescription appendFormat:
			 @"%@%@ = %@%@%@\n", 
			 indentation, 
			 key, 
			 isSingleLine ? @"" : @"\n",
			 thisDescription,
			 isSingleLine ? @";" : @""
			 ];
		}
	}
	
	return [nodeDescription autorelease];
	
}

/*************************** Accessors ***************************/

#pragma mark -
#pragma mark Accessors

- (void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
}

- (NSString *)title
{
	return [[title retain] autorelease];
}

- (void)setProperties:(NSDictionary *)newProperties
{
	if (properties != newProperties)
    {
        [properties autorelease];
        properties = [[NSMutableDictionary alloc] initWithDictionary:newProperties];
    }
}

- (NSMutableDictionary *)properties
{
	return [[properties retain] autorelease];
}

- (void)setChildren:(NSArray *)newChildren
{
	if (children != newChildren)
    {
        [children autorelease];
        children = [[NSMutableArray alloc] initWithArray:newChildren copyItems:YES];
    }
}

- (NSMutableArray *)children
{
	return [[children retain] autorelease];
}

- (void)setLeaf:(BOOL)flag
{
	isLeaf = flag;
	if (isLeaf)
		[self setChildren:[NSArray arrayWithObject:self]];
	else
		[self setChildren:[NSArray array]];
}

- (BOOL)isLeaf
{
	return isLeaf;
}

/*************************** Utility Methods ***************************/

/* For sorting */
- (NSComparisonResult)compare:(KBBaseNode *)aNode
{
	// Just return the result of comparing the titles
	return [[[self title] lowercaseString] compare:[[aNode title] lowercaseString]];
}

- (NSUInteger)countOfChildren;
{
	if (self.isLeaf)
		return 0;
	return [self.children count];
}

/*************************** Drag'n'Drop Convenience Methods ***************************/

#pragma mark -
#pragma mark Drag'n'Drop Convenience Methods

- (id)parentFromArray:(NSArray *)array
{
	for (id node in array)
	{
		if (node == self)	// If we are in the root array, return nil
			return nil;
		
		if ([[node children] containsObjectIdenticalTo:self])
			return node;
		
		if (![node isLeaf])
		{
			id innerNode = [self parentFromArray:[node children]];
			if (innerNode)
				return innerNode;
		}
	}
	return nil;
}

// Convenient recursive method
- (void)removeObjectFromChildren:(id)obj
{
	// Remove object from children or the children of any sub-nodes
	for (id node in children)
	{
		if(node == obj)
		{
			[children removeObjectIdenticalTo:obj];
			return;
		}
		
		if (![node isLeaf])
			[node removeObjectFromChildren:obj];
	}
}

- (NSArray *)descendants
{
	NSMutableArray *descendants = [NSMutableArray array];
	
	for (id node in children)
	{
		[descendants addObject:node];
		
		if (![node isLeaf])
			[descendants addObjectsFromArray:[node descendants]];	// Recursive - will go down the chain to get all
	}
	
	return descendants;
}

// This method is useful for generating a list of leaf-only nodes
- (NSArray *)allChildLeafs
{
	NSMutableArray *childLeafs = [NSMutableArray array];
	
	for (id node in children)
	{
		if ([node isLeaf])
			[childLeafs addObject:node];
		else
			[childLeafs addObjectsFromArray:[node allChildLeafs]];	// Recursive - will go down the chain to get all
	}
		
	return childLeafs;
}

- (NSArray *)groupChildren
{
	NSMutableArray *groupChildren = [NSMutableArray array];
	
	for (KBBaseNode *child in children)
	{
		if (![child isLeaf])
			[groupChildren addObject:child];
	}
	
	return groupChildren;
}

- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes
{
    // Returns YES if we are contained anywhere inside the array passed in, including inside sub-nodes.
	for (id node in nodes)
	{
		if (node == self) return YES;  // Found ourself
		
		// Check all sub-nodes
		if (![node isLeaf])
		{
			if ([self isDescendantOfOrOneOfNodes:[node children]])
				return YES;
		}
    }
	
	// Didn't find self inside any of the nodes passed in
    return NO;
}

- (BOOL)isDescendantOfNodes:(NSArray *)nodes
{
    // Returns YES if any node in the array passed in is an ancestor of ours.
	for (id node in nodes)
	{
		// Note that the only difference between this and isAnywhereInsideChildrenOfNodes: is that we don't check
		// to see if we are actually one of the items in the array passed in, only if we are one of their descendants.
		
		// Check sub-nodes
		if (![node isLeaf])
		{
			if ([self isDescendantOfOrOneOfNodes:[node children]])
				return YES;
		}
    }
	
	// Didn't find self inside any of the nodes passed in
	return NO;
	
}

- (NSIndexPath *)indexPathInArray:(NSArray *)array
{
	NSIndexPath *indexPath = nil;
	NSMutableArray *reverseIndexes = [NSMutableArray array];
	id parent, doc = self;
	NSUInteger index;
	while ((parent = [doc parentFromArray:array]))
	{
		index = [[parent children] indexOfObjectIdenticalTo:doc];
		if (index == NSNotFound)
			return nil;
		
		[reverseIndexes addObject:[NSNumber numberWithUnsignedInteger:index]];
		doc = parent;
	}
	
	// If parent is nil, we should just be in the parent array
	index = [array indexOfObjectIdenticalTo:doc];
	if (index == NSNotFound)
		return nil;
	[reverseIndexes addObject:[NSNumber numberWithUnsignedInteger:index]];
	
	// Now build the index path
	for (NSNumber *indexNumber in [reverseIndexes reverseObjectEnumerator])
	{
		if (indexPath == nil)
			indexPath = [NSIndexPath indexPathWithIndex:[indexNumber unsignedIntegerValue]];
		else
			indexPath = [indexPath indexPathByAddingIndex:[indexNumber unsignedIntegerValue]];
	}
	
	return indexPath;
}

/*************************** Archiving and Copying Support ***************************/

#pragma mark -
#pragma mark Archiving And Copying Support

+ (void)initialize
{
    if ( self == [KBBaseNode class] ) {
		mutableKeysArray = [[NSArray alloc] initWithObjects:
							@"title",
							@"properties",
							KBIsLeafKey,			// NOTE: isLeaf MUST come before children for initWithDictionary: to work properly!
							KBChildrenKey, 
							nil];
	}
}

+ (NSArray *)mutableKeys
{
	return mutableKeysArray;
}

- (NSArray *)mutableKeys
{
	return mutableKeysArray;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
	self = [self init];
	
	for (NSString *key in [self mutableKeys])
	{
		if ([key isEqualToString:KBChildrenKey])
		{
			if ([[dictionary objectForKey:KBIsLeafKey] boolValue])
				[self setChildren:[NSArray arrayWithObject:self]];
			else
			{
				// Get recursive!
				NSArray *dictChildren = [dictionary objectForKey:key];
				NSMutableArray *newChildren = [NSMutableArray array];
				for (NSDictionary *child in dictChildren)
				{
					id newNode = [[[self class] alloc] initWithDictionary:child];
					[newChildren addObject:newNode];
					[newNode release];
				}
				[self setChildren:newChildren];
			}
		}
		else
			[self setValue:[dictionary objectForKey:key] forKey:key];
	}
	
	return self;
	
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	for (NSString *key in [self mutableKeys])
	{
		// Convert all children to dictionaries too (note that we don't bother to look
		// at the children for leaf nodes, which should just hold a reference to self).
		if ([key isEqualToString:KBChildrenKey])
		{
			if (!isLeaf)
			{
				NSMutableArray *dictChildren = [NSMutableArray array];
				for (id child in children)
				{
					[dictChildren addObject:[child dictionaryRepresentation]];
				}
				[dictionary setObject:dictChildren forKey:key];
			}
		}
		else if ([self valueForKey:key])
			[dictionary setObject:[self valueForKey:key] forKey:key];
	}
	
	return dictionary;
	
}

- (id)initWithCoder:(NSCoder *)coder
{		
	self = [self init];	// Make sure all the instance variables are  initialised

	for (NSString *key in [self mutableKeys])
	{
		[self setValue:[coder decodeObjectForKey:key] forKey:key];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{	
	for (NSString *key in [self mutableKeys])
	{
		[coder encodeObject:[self valueForKey:key] forKey:key];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	id newNode = [[[self class] allocWithZone:zone] init];
	
	for (NSString *key in [self mutableKeys])
	{
		[newNode setValue:[self valueForKey:key] forKey:key];
	}
	
	return newNode;
}

// Subclasses must override this for any non-object values
- (void)setNilValueForKey:(NSString *)key
{
	if ([key isEqualToString:KBIsLeafKey])
		isLeaf = NO;
	else
		[super setNilValueForKey:key];
}

/*************************** Node Modification Convenience Methods ***************************/
#pragma mark -
#pragma mark Node Modification Convenience Methods

- (void)addObject:(id)object;
{
	if (self.isLeaf)
		return;
	[self.children addObject:object];
}

- (void)insertObject:(id)object inChildrenAtIndex:(NSUInteger)index;
{
	if (self.isLeaf)
		return;
	[self.children insertObject:object atIndex:index];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index;
{
	if (self.isLeaf)
		return;
	[self.children removeObjectAtIndex:index];
}

- (id)objectInChildrenAtIndex:(NSUInteger)index;
{
	if (self.isLeaf)
		return nil;
	return [self.children objectAtIndex:index];
}

- (void)replaceObjectInChildrenAtIndex:(NSUInteger)index withObject:(id)object;
{
	if (self.isLeaf)
		return;
	[self.children replaceObjectAtIndex:index withObject:object];
}
@end
