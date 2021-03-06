//
//  KBBaseNode.h
//  ------------
//
//	Keith Blount 2005
//  Jan Weiß 2010-2011
//
//  Multi-purpose node object for use with NSOutlineView and compatible with NSTreeController. Can be used as-is or
//	subclassed to add custom model attributes. Provides convenience methods for checking validitity of drag-and-drop
//	and cleaning up afterwards, and makes subclassing easy by providing convenience methods that make overriding
//	coding and copying methods in subclasses unnecessary.
//
//	Subclasses that add new variables *must* override -mutableKeys, adding the keys for the added variables.
//	If any of the variables are not objects (eg. ints, bools etc), the subclass must also override -setNilValueForKey:.
//	By overriding these two methods, there is no need for subclasses to override -initWithCoder:, -encodeWithCoder: or
//	-copyWithZone: - all of this will be handled by the superclass using the keys returned by -mutableKeys.
//

#import <Cocoa/Cocoa.h>

extern NSString * const KBChildrenKey;

@interface KBBaseNode : NSObject <NSCoding, NSCopying>

/* inits a leaf node (-init initialises a group node by default) */
- (id)initLeaf;

- (NSString *)descriptionWithLocale:(id)locale;
- (NSString *)descriptionWithChildren:(BOOL)describeChildren;
- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level;
- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level describeChildren:(BOOL)describeChildren;

/*************************** Properties ***************************/

@property (strong) NSString *title;
@property (strong) NSDictionary *properties;
@property (strong) NSArray *children;
@property (assign) BOOL isLeaf;

@property (nonatomic, weak) id parent;

/*************************** Utility Methods ***************************/

/* For sorting */
- (NSComparisonResult)compare:(KBBaseNode *)aNode;

/* Returns the count of child nodes */
- (NSUInteger)countOfChildren;


/*************************** Performance Optmization Methods ***************************/

// Use with care!
- (void)replaceChildren:(NSMutableArray *)newChildren;

/*************************** Archiving/Copying Support ***************************/

/* Subclasses should override these methods to maintain support for archiving and copying */
+ (NSArray *)mutableKeys;
- (NSArray *)mutableKeys;

/* Subclasses should override these methods to get automatic support for -description */
+ (NSArray *)describableKeys;
- (NSArray *)describableKeys;

/* Methods for converting the node to a simple dictionary, for XML support (note that all
   instance variables must be property list types for the dictionary to be written out as XML, though) */
- (NSDictionary *)dictionaryRepresentation;
- (id)initWithDictionary:(NSDictionary *)dictionary;

/*************************** Drag'n'Drop Convenience Methods ***************************/

/*	Finds the parent of the receiver from the nodes contained in the array */
- (id)parentFromArray:(NSArray *)array DEPRECATED_ATTRIBUTE; // Use the parent property instead!

/*	Searches children and children of all sub-nodes to remove given object */
- (void)removeObjectFromChildren:(id)obj;

/* Generates an array of all descendants */
- (NSArray *)descendants;

/*	Generates an array of all leafs in children and children of all sub-nodes */
- (NSArray *)allChildLeafs;

/*	Returns only the children that are group nodes (used by browser for showing only groups, for instance) */
- (NSArray *)groupChildren;

/*	Returns YES if self is contained anywhere inside the children or children of sub-nodes of the nodes contained
	inside the given array */
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes;

/* Returns YES if self is a descendent of any of the nodes in the given array */
- (BOOL)isDescendantOfNodes:(NSArray *)nodes;

/* Returns the index path of self within the given array - useful for dragging and dropping */
- (NSIndexPath *)indexPathInArray:(NSArray *)array;

/*************************** Node Modification Convenience Methods ***************************/

- (void)addObject:(KBBaseNode *)object;

- (void)insertObject:(KBBaseNode *)object inChildrenAtIndex:(NSUInteger)index;

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index;

- (id)objectInChildrenAtIndex:(NSUInteger)index;

- (void)replaceObjectInChildrenAtIndex:(NSUInteger)index withObject:(KBBaseNode *)object;

#pragma mark -
#pragma mark Tree Enumeration Helper Methods

- (KBBaseNode *)rootAncestor;
- (KBBaseNode *)nextSibling;
- (KBBaseNode *)nextNode;

@end
