# BMQuadtree

Swift implementation of a Quadtree. A drop-in replacement for GameplayKit's GKQuadtree [for it is not working properly](https://forums.developer.apple.com/thread/53458).

A quadtree manages its structure to optimize for spatial searches—unlike a basic data structure such as an array or dictionary, a quadtree can find all elements occupying a specific position or region very quickly. The quadtree partitioning strategy divides space into four quadrants at each level, as illustrated in Figure 1. When a quadrant contains more than one object, the tree subdivides that region into four smaller quadrants, adding a level to the tree.

![Figure 1](https://docs-assets.developer.apple.com/published/1a079d3016/quadtree_2x_f3a2f6b0-7e06-4d82-bb5d-33861c64ecd7.png)

The tree can hold any objects (`AnyObject`). The implementation follows the `GKQuadtree`.

## Creating A Tree

A tree is initialised with a bounding quad (axis-aligned bounding rectangle) and a minimum cell size.

```swift
let tree = BMQuadtree(
  boundingQuad: boundingQuad,
  minimumCellSize: 3)
```

The minCellSize parameter controls the memory usage and performance of the tree. A lower value causes the tree to make more spatial divisions when adding elements; a higher value causes the tree to create fewer such divisions, but store more elements in each node. Which direction leads to better performance depends on the number and spatial arrangement of the elements you add to the tree—for best results, profile with different values to find one best suited to your app or game.

## Adding and Removeing Elements

```swift
  let location = CLLocation(latitude: item.latitude, longitude: item.longitude)
  tree.add(location, at: float2(item.latitude, item.longitude))
```

## Searching for Elements

```swift
/// Nearest neighbour
let nearest = tree.element(nearestTo: float2(0, 0))
```


```swift
/// Nearest neighbour of a specific type
let nearestOfType: CLLocation? =
  tree
    .element(nearestTo: float2(0, 0), type: CLLocation.self) as? CLLocation
```

```swift
/// All of the elements in the quadtree node this
/// point would be placed in.
let elementAtPoint = tree.elements(at: float2(0, 0))
```

```swift
/// All of the elements that resides in quadtree nodes which
/// intersect the given quad. Recursively check if the earch quad contains
/// the points in the quad.
let searchQuad = GKQuad(quadMin: float2(-10, -10), quadMax: float2(10, 10))
let elementInQuad = tree.elements(in: searchQuad)
```

# Extensions for MapKit

To be able to use the quadtree for managing map data (locations, coordinates, instructions, POIs, etc.), there are a few extensions available for your convenience.

**Initialising a `GKQuad` using a location and offset.**

`GKQuad.init(location: CLLocation, offset: CLLocationDistance)`

**`GKQuad` for overlays**

`MKOverlay.boundingQuad: GKQuad`

**`CLLocationCoordinate2D` and `CLLocation` to `vector_float2`**

`CLLocationCoordinate2D.vector`, `CLLocation.vector`

**Debugging the tree on the map**

`BMQuadtree.debugOverlay`


