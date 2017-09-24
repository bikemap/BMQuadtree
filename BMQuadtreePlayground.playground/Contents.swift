//: Playground - noun: a place where people can play

import Foundation
import MapKit
import GameplayKit

/// We are going to setup a large tree with 100 random CLLocation objects.
let largeTree: BMQuadtree<AnyObject>?
var largeCoordinateSet: [CLLocationCoordinate2D] = []

/// Using the random generator from GameplayKit to generate the coordinates.
let rand = GKMersenneTwisterRandomSource()
let distribution = GKRandomDistribution(
  randomSource: rand,
  lowestValue: 0,
  highestValue: 100)

/// Generating and adding the coordinates to the set.
for _ in 0..<100 {
  let latitude: CLLocationDegrees =
    CLLocationDegrees(distribution.nextInt())
  let longitude: CLLocationDegrees =
    CLLocationDegrees(distribution.nextInt())
  let coordinate = CLLocationCoordinate2D(
    latitude: latitude,
    longitude: longitude)
  largeCoordinateSet.append(coordinate)
}

// MARK: - Creating The Tree
//
/// We create and overlay to get the bounding quad of all the coordinates.
/// See BMQuadtree+MapKit for details.
let largeOverlay = MKPolyline(
  coordinates: largeCoordinateSet,
  count: largeCoordinateSet.count)

/// Creating the tree. The minimum cell size can be any integer. The smaller
/// the number, the faster the search within th quads, but larger the tree.
largeTree = BMQuadtree(
  boundingQuad: largeOverlay.boundingQuad,
  minimumCellSize: 3,
  maximumDepth: 100)

/// Then we add the coordinates to the tree.
for item in largeCoordinateSet {
  let location = CLLocation(latitude: item.latitude, longitude: item.longitude)
  largeTree?.add(location, at: item.vector)
}

// MARK: - Searching For Elements

/// Nearest neighbour
let nearest = largeTree?.element(nearestTo: float2(0, 0))

/// Nearest neighbour of a specific type
let nearestOfType: CLLocation? =
  largeTree?
    .element(nearestTo: float2(0, 0), type: CLLocation.self) as? CLLocation

/// All of the elements in the quadtree node this
/// point would be placed in.
let elementAtPoint = largeTree?.elements(at: float2(0, 0))

/// All of the elements that resides in quad tree nodes which
/// intersect the given quad. Recursively check if the earch quad contains
/// the points in the quad.
let searchQuad = GKQuad(quadMin: float2(-10, -10), quadMax: float2(10, 10))
let elementInQuad = largeTree?.elements(in: searchQuad)
