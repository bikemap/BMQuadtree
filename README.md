# BMQuadtree

Swift implementation of a Quadtree. A drop-in replacement for GameplayKit's 
GKQuadtree [for it is not working properly](https://forums.developer.apple.com/thread/53458).

A quadtree manages its structure to optimize for spatial searches—unlike a basic 
data structure such as an array or dictionary, a quadtree can find all elements 
occupying a specific position or region very quickly. The quadtree partitioning 
strategy divides space into four quadrants at each level, as illustrated in 
Figure 1. When a quadrant contains more than one object, the tree subdivides 
that region into four smaller quadrants, adding a level to the tree.

![Figure 1](https://docs-assets.developer.apple.com/published/1a079d3016/quadtree_2x_f3a2f6b0-7e06-4d82-bb5d-33861c64ecd7.png)

The tree can hold any objects (`AnyObject`). 
The implementation follows the `GKQuadtree`.

The implementation is using [Axis-Aligned Bounding Boxed (AABB)](https://en.wikipedia.org/wiki/Minimum_bounding_box#Axis-aligned_minimum_bounding_box) just like the GameplayKit implementation.

## TODO

* [ ] Dependency managers (cocoapods, carthage, swiftpm)
* [ ] Unify/clean-up after removing object from tree
* [ ] Add object to quadtree with a given quad
* [ ] Remove object from the given quadtree node

## Creating A Tree

A tree is initialised with a bounding quad (axis-aligned bounding rectangle), 
a minimum cell size and a maximum depth.

```swift
let tree = BMQuadtree(
  boundingQuad: boundingQuad,
  minimumCellSize: 3)
```

By default, the minimum cell size is 1, but it does make sense to use a larger
cell size, for instance 3.

## Adding And Removing Elements

```swift
  let location = CLLocation(latitude: item.latitude, longitude: item.longitude)
  tree.add(location, at: float2(item.latitude, item.longitude))
```

```swift
  tree.remove(location)
```

## Searching For Elements

Nearest neigbour to a defined point.

```swift
let nearest = tree.element(nearestTo: float2(0, 0))
```

You filter for different types (classes) when performing a nearest element
search.

```swift
let nearestOfType: CLLocation? =
  tree.element(
  	nearestTo: float2(0, 0), 
  	type: CLLocation.self) as? CLLocation
```

All of the elements in the quadtree node this point would be placed in.

```swift
let elementAtPoint = tree.elements(at: float2(0, 0))
```

All of the elements that resides in quadtree nodes which
intersect the given quad. Recursively check if the earch quad contains
the points in the quad.

```swift
let searchQuad = GKQuad(
	quadMin: float2(-10, -10), 
	quadMax: float2(10, 10))

let elementInQuad = tree.elements(in: searchQuad)
```

# Extensions for MapKit

To be able to use the quadtree for managing map data (locations, coordinates, 
instructions, POIs, etc.), there are a few extensions available 
for your convenience.

## `GKQuad` With CLLocation And Offset

To define a quad using coordinated and offset in meters.

```swift
let vienna = CLLocation(latitude: 48.21128, longitude: 16.364537)
let quad = GKQuad(location: vienna, offset: 5000)
```

## `GKQuad` For Overlays

Let us say you have a track you show on the map as an`MKOverlay`. 
You can access the bounding quad using:

```swift
let quad = trackOverlay.boundingQuad
```

## `CLLocationCoordinate2D` And `CLLocation` To `vector_float2`

As float2-s are used to store the location of the objects, we added 
convenience properties to work with `CLLocation` and `CLLocationCoordinate2D`

```swift
let vienna = CLLocation(latitude: 48.21128, longitude: 16.364537)
let vector = vienna.vector
```

```swift
let vienna = CLLocationCoordinate2DMake(latitude: 48.21128, longitude: 16.364537)
let vector = vienna.vector
```

## Debugging

Finally, to be able to visualise and debug the quadtree on the map, you 
can use the convenience `debugOverlay` property of the tree and simply add it
as a new overlay.

```swift
let quadtreeDebugOverlay: MKOverlay = tree?.debugOverlay
map.add(quadtreeDebugOverlay)
```

## Further Dicussions

The **minCellSize** parameter controls the memory usage and performance of the 
tree. A lower value causes the tree to make more spatial divisions when adding 
elements; a higher value causes the tree to create fewer such divisions, 
but store more elements in each node. Which direction leads to better 
performance depends on the number and spatial arrangement of the elements you 
add to the tree—for best results, profile with different values to find one 
best suited to your app or game.

The **maximum depth** is added for performance reasons and to aviod stack
overflow crashed when adding the same or very close elements in large numbers.
The default value is 10. This limits the maximum amount of elements to be 
stored in the tree:

```
numberOfNodes ^ maximumDepth * minCellSize
4 ^ 10 * 3 = 3.145.728
```

```swift
let largeTree = BMQuadtree(
  boundingQuad: largeOverlay.boundingQuad,
  minimumCellSize: 10,
  maximumDepth: 100)
```