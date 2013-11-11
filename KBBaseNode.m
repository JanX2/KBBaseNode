//
//  KBBaseNode.m
//  --------
//
//  Keith Blount 2005
//  Jan Weiß 2010-2013
//

#import "KBBaseNode.h"
#import "NSArray+KBExtensions.h"

NSString * const KBChildrenKey = @"children";
NSString * const KBIsLeafKey = @"isLeaf";

NSString * KBDescriptionForObject(id object, id locale, NSUInteger indentLevel)
{
	NSString *descriptionString;
	BOOL addQuotes = NO;
	
	if ([object isKindOfClass:[NSString class]]) {
		descriptionString = object;
	}
	else if ([object respondsToSelector:@selector(descriptionWithLocale:indent:)]) {
		return [(id)object descriptionWithLocale:locale indent:indentLevel];
	}
	else if ([object respondsToSelector:@selector(descriptionWithLocale:)]) {
		return [(id)object descriptionWithLocale:locale];
	}
	else {
		descriptionString = [object description];
	}
	
	NSRange range = [descriptionString rangeOfString:@" "];
	if (range.location != NSNotFound) {
		addQuotes = YES;
	}
	
	if (addQuotes) {
		return [NSString stringWithFormat:@"\"%@\"", descriptionString];
	}
	else {
		return descriptionString;
	}
}

@implementation KBBaseNode {
	NSMutableDictionary *_properties;
	NSMutableArray *_children;
	BOOL _isLeaf;
}

@dynamic properties, children, isLeaf;

#pragma mark -
#pragma mark Object Lifecycle

- (id)init
{
	self = [super init];
	
	if (self) {
		_title = @"Untitled";
		_properties = [@{} mutableCopy];
		_children = [@[] mutableCopy];
		_isLeaf = NO;				 			    // Container by default.
	}
	
	return self;
}

- (id)initLeaf
{
	self = [self init];
	
	if (self) {
		_isLeaf = YES;
	}
	
	return self;
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
	
	NSString *indentationString = @"    ";
	NSUInteger indentationStringLength = indentationString.length;
	
	NSUInteger indentationDepth = (level+1) * indentationStringLength;
	NSUInteger indentationDepth2 = (level+2) * indentationStringLength;
	
	NSString *indentation = [@"" stringByPaddingToLength:indentationDepth withString:indentationString startingAtIndex:0];
	NSString *indentation2 = [@"" stringByPaddingToLength:indentationDepth2 withString:indentationString startingAtIndex:0];
	
	for (NSString *key in [self describableKeys]) {
		if ([key isEqualToString:KBChildrenKey]) {
			if (describeChildren && !_isLeaf) {
				[nodeDescription appendFormat:@"%@%@ = (\n", indentation, KBChildrenKey];
				id lastChild = [_children lastObject];
				
				for (id child in _children) {
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
	
	return nodeDescription;
}


#pragma mark -
#pragma mark Accessors

- (void)setProperties:(NSDictionary *)newProperties
{
	if (_properties != newProperties) {
		_properties = [newProperties mutableCopy];
	}
}

- (NSMutableDictionary *)properties
{
	return _properties;
}

- (void)setChildren:(NSArray *)newChildren
{
	if (_children != newChildren) {
		_children = [[NSMutableArray alloc] initWithArray:newChildren copyItems:YES];
	}
}

- (NSMutableArray *)children
{
	return _children;
}

- (void)setIsLeaf:(BOOL)flag
{
	if (_isLeaf != flag) {
		_isLeaf = flag;
		
		if (_isLeaf) {
			[_children removeAllObjects];
		}
	}
}

- (BOOL)isLeaf
{
	return _isLeaf;
}


#pragma mark -
#pragma mark Utility Methods

/**
 * For sorting.
 */
- (NSComparisonResult)compare:(KBBaseNode *)aNode
{
	return [self.title compare:aNode.title
					   options:NSCaseInsensitiveSearch];
}

- (NSUInteger)countOfChildren;
{
	if (_isLeaf) {
		return 0;
	}
	
	return _children.count;
}


#pragma mark -
#pragma mark Drag'n'Drop Convenience Methods

- (id)parentFromArray:(NSArray *)array
{
	for (KBBaseNode *node in array) {
		if (node == self) {     // If we are in the root array, return nil
			return nil;
		}
		
		if ([[node children] containsObjectIdenticalTo:self]) {
			// node is the parent of self.
			return node;
		}
		
		if (node.isLeaf == NO) {
			// Go deeper.
			id innerNode = [self parentFromArray:[node children]];
			if (innerNode) {
				return innerNode;
			}
		}
	}
	
	return nil;
}

/**
 * Recursive method which searches children and children of all sub-nodes
 * to remove the given object.
 */
- (void)removeObjectFromChildren:(id)obj
{
	// Remove object from children or the children of any sub-nodes
	for (KBBaseNode *node in _children) {
		if (node == obj) {
			[_children removeObjectIdenticalTo:obj];
			return;
		}
		
		if (node.isLeaf == NO) {
			[node removeObjectFromChildren:obj];
		}
	}
}

/**
 * Generates an array of all descendants.
 */
- (NSArray *)descendants
{
	NSMutableArray *descendants = [NSMutableArray array];
	
	for (KBBaseNode *node in _children) {
		[descendants addObject:node];
		
		if (node.isLeaf == NO) {
			[descendants addObjectsFromArray:[node descendants]];    // Recursive - will go down the chain to get all
		}
	}
	
	return descendants;
}

/**
 * Generates an array of all leafs in children and children of all sub-nodes.
 * Useful for generating a list of leaf-only nodes.
 */
- (NSArray *)allChildLeafs
{
	NSMutableArray *childLeafs = [NSMutableArray array];
	
	for (KBBaseNode *node in _children) {
		if (node.isLeaf) {
			[childLeafs addObject:node];
		}
		else {
			[childLeafs addObjectsFromArray:[node allChildLeafs]];    // Recursive - will go down the chain to get all
		}
	}
	
	return childLeafs;
}

/**
 * Returns only the children that are group nodes.
 */
- (NSArray *)groupChildren
{
	NSMutableArray *groupChildren = [NSMutableArray array];
	
	for (KBBaseNode *child in _children) {
		if (child.isLeaf == NO) {
			[groupChildren addObject:child];
		}
	}
	
	return groupChildren;
}

/**
 * Returns YES if self is contained anywhere inside the children or children of
 * sub-nodes of the nodes contained inside the given array.
 */
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes
{
	// Returns YES if we are contained anywhere inside the array passed in, including inside sub-nodes.
	for (KBBaseNode *node in nodes) {
		if (node == self) {
			return YES; // We found ourself.
		}
		
		// Check all the sub-nodes.
		if (![node isLeaf]) {
			if ([self isDescendantOfOrOneOfNodes:[node children]]) {
				return YES;
			}
		}
	}
	
	// Didn't find self inside any of the nodes passed in.
	return NO;
}

/**
 * Returns YES if any node in the array passed in is an ancestor of ours.
 */
- (BOOL)isDescendantOfNodes:(NSArray *)nodes
{
	// Returns YES if any node in the array passed in is an ancestor of ours.
	for (KBBaseNode *node in nodes) {
		// Note that the only difference between this and isAnywhereInsideChildrenOfNodes: is that we don't check
		// to see if we are actually one of the items in the array passed in, only if we are one of their descendants.
		
		// Check all the sub-nodes.
		if (node.isLeaf == NO) {
			if ([self isDescendantOfOrOneOfNodes:[node children]]) {
				return YES;
			}
		}
	}
	
	// Didn't find self inside any of the nodes passed in.
	return NO;
}

/**
 * Returns the index path of within the given array, useful for drag and drop.
 */
- (NSIndexPath *)indexPathInArray:(NSArray *)array
{
	NSIndexPath *indexPath = nil;
	NSMutableArray *reverseIndexes = [NSMutableArray array];
	id parent, doc = self;
	NSUInteger index;
	
	while ((parent = [doc parentFromArray:array])) {
		index = [[parent children] indexOfObjectIdenticalTo:doc];
		if (index == NSNotFound) {
			return nil;
		}
		
		[reverseIndexes addObject:@(index)];
		doc = parent;
	}
	
	// If parent is nil, we should just be in the parent array
	index = [array indexOfObjectIdenticalTo:doc];
	if (index == NSNotFound) {
		return nil;
	}
	
	[reverseIndexes addObject:@(index)];
	
	// Now build the index path.
	NSEnumerator *re = [reverseIndexes reverseObjectEnumerator];
	for (NSNumber *indexNumber in re) {
		if (indexPath == nil) {
			indexPath = [NSIndexPath indexPathWithIndex:[indexNumber unsignedIntegerValue]];
		}
		else {
			indexPath = [indexPath indexPathByAddingIndex:[indexNumber unsignedIntegerValue]];
		}
	}
	
	return indexPath;
}


#pragma mark -
#pragma mark Archiving and Copying Support

+ (NSArray *)mutableKeys;
{
	static NSArray *mutableKeys = nil;
	if (mutableKeys == nil) {
		mutableKeys = @[@"title",
		                @"properties",
		                KBIsLeafKey,            // NOTE: isLeaf MUST come before children for initWithDictionary: to work properly!
		                KBChildrenKey];
	}
	
	return mutableKeys;
}

/**
 * Override this method to maintain support for archiving and copying.
 */
- (NSArray *)mutableKeys;
{
	return [KBBaseNode mutableKeys];
}

+ (NSArray *)describableKeys;
{
	static NSArray *describableKeys = nil;
	if (describableKeys == nil) {
#if REMOVE_REDUNDANT_LEAF_KEY
		NSMutableArray *describableKeys = [self.mutableKeys mutableCopy];
		[describableKeys removeObject:KBIsLeafKey];
		describableKeys = @[describableKeys];
#else
		describableKeys = [self mutableKeys];
#endif
	}
	
	return describableKeys;
}

- (NSArray *)describableKeys;
{
	return [KBBaseNode describableKeys];
}


- (id)initWithDictionary:(NSDictionary *)dictionary
{
	self = [self init];
	
	if (self) {
		for (NSString *key in [self mutableKeys]) {
			if ([key isEqualToString:KBChildrenKey]) {
				if ([dictionary[KBIsLeafKey] boolValue]) {
					[self setChildren:@[]];
				}
				else {
					// Get recursive!
					NSArray *dictChildren = dictionary[key];
					NSMutableArray *newChildren = [NSMutableArray array];
					
					for (NSDictionary *childDict in dictChildren) {
						id newNode = [[[self class] alloc] initWithDictionary:childDict];
						[newChildren addObject:newNode];
					}
					
					[self setChildren:newChildren];
				}
			}
			else {
				[self setValue:dictionary[key] forKey:key];
			}
		}
	}
	
	return self;
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	
	for (NSString *key in [self mutableKeys]) {
		// Convert all children to dictionaries.
		if ([key isEqualToString:KBChildrenKey]) {
			if (!_isLeaf) {
				NSMutableArray *dictChildren = [NSMutableArray array];
				for (KBBaseNode *child in _children) {
					[dictChildren addObject:[child dictionaryRepresentation]];
				}
				
				dictionary[key] = dictChildren;
			}
		}
		else if ([self valueForKey:key]) {
			dictionary[key] = [self valueForKey:key];
		}
	}
	
	return dictionary;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [self init];    // Make sure all the instance variables are initialised.
	
	if (self) {
		for (NSString *key in [self mutableKeys]) {
			[self setValue:[coder decodeObjectForKey:key] forKey:key];
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	for (NSString *key in [self mutableKeys]) {
		[coder encodeObject:[self valueForKey:key] forKey:key];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	id newNode = [[[self class] allocWithZone:zone] init];
	
	for (NSString *key in [self mutableKeys]) {
		[newNode setValue:[self valueForKey:key] forKey:key];
	}
	
	return newNode;
}

/**
 * Subclasses must override this for any non-object values.
 */
- (void)setNilValueForKey:(NSString *)key
{
	if ([key isEqualToString:KBIsLeafKey]) {
		_isLeaf = NO;
	}
	else {
		[super setNilValueForKey:key];
	}
}


#pragma mark -
#pragma mark Node Modification Convenience Methods

- (void)addObject:(id)object;
{
	if (_isLeaf) {
		return;
	}
	
	[_children addObject:object];
}

- (void)insertObject:(id)object inChildrenAtIndex:(NSUInteger)index;
{
	if (_isLeaf) {
		return;
	}
	
	[_children insertObject:object atIndex:index];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index;
{
	if (_isLeaf) {
		return;
	}
	
	[_children removeObjectAtIndex:index];
}

- (id)objectInChildrenAtIndex:(NSUInteger)index;
{
	if (_isLeaf) {
		return nil;
	}
	
	return (_children)[index];
}

- (void)replaceObjectInChildrenAtIndex:(NSUInteger)index withObject:(id)object;
{
	if (_isLeaf) {
		return;
	}
	
	(_children)[index] = object;
}
@end
