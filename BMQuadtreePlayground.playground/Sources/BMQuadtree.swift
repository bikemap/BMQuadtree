//
//  BMQuadrree.swift
//  Bikemap
//
//  Created by Adam Eri on 22/06/2017.
//  Copyright © 2017 Bikemap GmbH. Apache License 2.0
//

import Foundation
import GameplayKit

public class BMQuadtreeNode <T: AnyObject>: GKQuadtreeNode {
  public var tree: BMQuadtree<T>

  public init(tree: BMQuadtree<T>) {
    self.tree = tree
    super.init()
  }
}

extension GKQuad {

  /// Checks if the point specified is within this quad.
  ///
  /// - Parameter point: the point to query
  /// - Returns: Returns true if the point specified is within this quad.
  public func contains(_ point: vector_float2) -> Bool {

    // Above lower left corner
    let gtMin = (point.x >= self.quadMin.x && point.y >= self.quadMin.y)

    // Below upper right coner
    let leMax = (point.x <= self.quadMax.x && point.y <= self.quadMax.y)

    // If both is true, the point is inside the quad.
    return (gtMin && leMax)
  }

  /// Checks if the specified quad intersects with self.
  ///
  /// - Parameter quad: the quad to query
  /// - Returns: Returns true if the quad intersects
  public func intersects(_ quad: GKQuad) -> Bool {

    if self.quadMin.x > quad.quadMax.x ||
      self.quadMin.y > quad.quadMax.y {
      return false
    }

    if self.quadMax.x < quad.quadMin.x ||
      self.quadMax.y < quad.quadMin.y {
      return false
    }

    return true
  }
}

/// The BMQuadtree is an almost drop-in replacement for the GKQuadtree,
/// as that one is reportedly not working as of iOS10.
/// 
/// A tree data structure where each level has 4 children that subdivide a 
/// given space into the four quadrants.
/// Stores arbitrary data of any class via points and quads.
final public class BMQuadtree <T: AnyObject> {

  /// Typealias to use for objects stored in the tree
  public typealias Object = (T, vector_float2)

  // Bounding quad
  var quad: GKQuad

  /// Child Quad Trees
  var northWest: BMQuadtree?
  var northEast: BMQuadtree?
  var southWest: BMQuadtree?
  var southEast: BMQuadtree?

  /// The depth of the tree
  var depth: Int64 = 0

  /// The maximum depth of the tree. The limit is there to avoid infinite loops
  /// when adding the same, or very close elements in large numbers.
  /// This limits the maximum amount of elements to be stored in the tree:
  /// numberOfNodes ^ maximumDepth * minCellSize
  /// 4 ^ 10 * 3 = 3.145.728
  private var maximumDepth: Int64

  // MARK: - Initialise

  public init(
    boundingQuad quad: GKQuad,
    minimumCellSize minCellSize: Float = 1,
    maximumDepth: Int64 = 10) {
    self.quad = quad
    self.minCellSize = minCellSize
    self.maximumDepth = maximumDepth
  }

  // MARK: - Adding Elements

  /// Adds an NSObject to this quadtree with a given point.
  /// This data will always reside in the leaf node its point is in.
  ///
  /// - Parameters:
  ///   - element: the element to store
  ///   - point: the point associated with the element you want to store
  /// - Returns: the quadtree node the element was added to
  @discardableResult
  public func add(_ element: T, at point: vector_float2) -> BMQuadtreeNode<T>? {
    
    // Checking if the point specified should be within this quad.
    // With the initial tree, it is always true. This comes handy when
    // subdividing the quad and need to place the object to a specific quad.
    if self.quad.contains(point) == false {
      return nil
    }

    // We check the minCellSize to see if the object still fits and that the
    // tree has no leafs. If it has, the point goes into the leafs.
    if Float(self.objects.count) < self.minCellSize,
      self.hasQuads == false {
      self.objects.append((element, point))
      return BMQuadtreeNode(tree: self)
    }

    // Otherwise, subdivide and add the point to whichever child will accept it
    if self.hasQuads == false {

      // If we try to add multiple elements with the same coordinates, it
      // might result in an infinite loop. When the bucket size is smaller
      // than the number of identical elements, subdivide goes on unitl stack
      // overflow.
      // To fix this, we return nil here when there are already elements in
      // this quad for the same coordinates and the quad's bucket is full.
      // Id est: we can olny store as many identical points as the size of the
      /// minimal cell size.
      let existingElements = self
        .objects
        .filter({ $0.1.x == point.x && $0.1.y == point.y })

      guard Float(existingElements.count) < self.minCellSize else {
        return nil
      }

      guard self.depth < self.maximumDepth else {
        return nil
      }

      self.subdivide()
    }

    // Relocate the tree's object to the leafs
    for object in self.objects {
      if self.northWest!.add(object.0, at: object.1) != nil {
        continue
      } else if self.northEast!.add(object.0, at: object.1) != nil {
        continue
      } else if self.southWest!.add(object.0, at: object.1) != nil {
        continue
      } else if self.southEast!.add(object.0, at: object.1) != nil {
        continue
      }
    }

    if self.hasQuads == true {
      self.objects.removeAll()
    }

    // Adding the new point to the leafs.
    // If necessary, this will take care of the multiple splitting
    if let NW = self.northWest!.add(element, at: point) {
      return NW
    } else if let NE = self.northEast!.add(element, at: point) {
      return NE
    } else if let SW = self.southWest!.add(element, at: point) {
      return SW
    } else if let SE = self.southEast!.add(element, at: point) {
      return SE
    }

    // It should never actually fail.
    return nil
  }

  /**
   * Adds an NSObject to this quadtree with a given quad.
   * This data will reside in the lowest node that its quad fits in completely.
   *
   * @param data the data to store
   * @param quad the quad associated with the element you want to store
   * @return the quad tree node the element was added to
   */
//  open func add(_ element: ElementType, in quad: GKQuad) -> GKQuadtreeNode

  // MARK: - Searching For Elements

  /// Returns all of the elements in the quadtree node this 
  /// point would be placed in.
  ///
  /// - Parameter point: the point to query
  /// - Returns: an NSArray of all the data found at the quad tree node this
  /// point would be placed in
  public func elements(at point: vector_float2) -> [T] {

    var elements: [T] = []

    // If point is outside the tree bounds, return empty array.
    if self.quad.contains(point) == false {
      return elements
    }

    if self.hasQuads == false {
      elements = self.objects.flatMap({ $0.0 })
    } else {
      elements.append(contentsOf: self.northWest!.elements(at: point))
      elements.append(contentsOf: self.northEast!.elements(at: point))
      elements.append(contentsOf: self.southWest!.elements(at: point))
      elements.append(contentsOf: self.southEast!.elements(at: point))
    }
    return elements
  }

  /// Returns all of the elements that resides in quad tree nodes which
  /// intersect the given quad. Recursively check if the earch quad contains
  /// the points in the quad.
  ///
  /// - Parameter quad: the quad you want to test
  /// - Returns: an NSArray of all the elements in all of the nodes that
  /// intersect the given quad
  public func elements(in quad: GKQuad) -> [T] {

    var elements: [T] = []

    // Return if the search quad does not intersect with self.

    if self.quad.intersects(quad) == false {
      return elements
    }

    if self.hasQuads == false {
      // If there is no leaf, filter the objects, which are in the searchQuad.
      elements = self
        .objects
        .filter({ quad.contains($0.1) })
        .flatMap({ $0.0 })
    } else {
      elements.append(contentsOf: self.northWest!.elements(in: quad))
      elements.append(contentsOf: self.northEast!.elements(in: quad))
      elements.append(contentsOf: self.southWest!.elements(in: quad))
      elements.append(contentsOf: self.southEast!.elements(in: quad))
    }

    return elements
  }

  /// Returns the element nearest ot the specified point.
  ///
  /// - Parameter point: The point used for the search
  /// - Returns: The nearest element in the tree to the specified point, or nil
  /// if the tree is empty
  public func element(nearestTo point: vector_float2) -> T? {
    let nearestElement =
      self.element(nearestTo: point, type: AnyObject.self, nearest: nil)
    return nearestElement?.element
  }

  /// Returns the element of the specified type nearest ot the specified point.
  ///
  /// - Parameter:
  ///   - point: The point used for the search
  ///   - type: The type of elements to search for
  /// - Returns: The nearest element in the tree to the specified point, or nil
  /// if the tree is empty
  public func element<U: AnyObject>(
    nearestTo point: vector_float2,
    type: U.Type) -> T? {

    let nearestElement =
      self.element(nearestTo: point, type: type, nearest: nil)
    return nearestElement?.element
  }

  /// A custom type for the nearest element, a tuple containing the actual
  /// element in the tree, plus the distance to the specified point.
  typealias NearestElement = (element: T, distance: Float)

  /// Returns the object nearest ot the specified point.
  ///
  /// Performs a lookup in the tree and it's subquads for objects, which are
  /// near the specified point.
  ///
  /// The objects might be in the same quad or in neigbouring quads.
  /// We exculde quads, which are further on any axis then the last found
  /// nearest element. This way we minimise the number of Euclidean distance
  /// calculations.
  ///
  /// - Parameters:
  ///   - point: The point used for the search
  ///   - nearest: The last found nearest element
  /// - Returns: The nearest object in the tree to the specified point, or nil
  private func element<U: AnyObject>(
    nearestTo point: vector_float2,
    type: U.Type,
    nearest: NearestElement? = nil) -> NearestElement? {
    var nearestElement = nearest

    let a = point.x
    let b = point.y
    let x1 = self.quad.quadMin.x
    let y1 = self.quad.quadMin.y
    let x2 = self.quad.quadMax.x
    let y2 = self.quad.quadMax.y

    // Distance is either the distance to the last found nearest element
    // or the full width of the node.
    let shortestDistance: Float = nearestElement?.distance ?? x2 - x1

    // We exculde quads, which are further on any axis then the last found
    // nearest element. This way we minimise the number of Euclidean distance
    // calculations.
    if a - shortestDistance > x2 ||
      b + shortestDistance < y1 ||
      a + shortestDistance < x1 ||
      b - shortestDistance > y2 {
      return nearest
    }

    if self.hasQuads == false && self.objects.count > 0 {

      // Test the elements of the node by calculating Euclidean distance to the
      // point.
      for object in self.objects {

        // Filter for the specified type
        if type != AnyObject.self, Swift.type(of: object.0) != type {
          continue
        }

        let dx = object.1.x - a
        let dy = object.1.y - b
        let distance = sqrt(dx * dx + dy * dy)

        if distance < shortestDistance {
          nearestElement = (object.0, distance)
        }
      }
    } else {
      // Scanning the sub-nodes for nearest element
      nearestElement = self
        .northWest?
        .element(nearestTo: point, type: type, nearest: nearestElement) ??
      nearestElement

      nearestElement = self
        .northEast?
        .element(nearestTo: point, type: type, nearest: nearestElement) ??
      nearestElement

      nearestElement = self
        .southWest?
        .element(nearestTo: point, type: type, nearest: nearestElement) ??
      nearestElement

      nearestElement = self
        .southEast?
        .element(nearestTo: point, type: type, nearest: nearestElement) ??
      nearestElement
    }
    return nearestElement
  }

  // MARK: - Removing Elements

  /// Removes the given NSObject from this quad tree.
  /// If there are no more items in the node, we try unifying. See `unify()`.
  ///
  /// Note that this is an exhaustive search and is slow.
  /// Cache the relevant GKQuadTreeNode and use removeElement:WithNode: 
  /// for better performance.
  ///
  /// - Parameter element: the data to be removed
  /// - Returns: returns true if the data was removed, false otherwise
  public func remove(_ element: T) -> Bool {

    if self.hasQuads == false {
      // Node does not contain this element
      let index = self.objects.index { element === $0.0 }

      guard index != nil,
        index! >= 0 else {
        return false
      }

      // Removing element
      self.objects.remove(at: index!)

      // Try unifying quads if node is empty
      if self.objects.count == 0 {
        self.parent?.unify()
      }

      return true
    } else {

      // Trying to remove from all child nodes
      let nw = self.northWest!.remove(element)
      let ne = self.northEast!.remove(element)
      let sw = self.southWest!.remove(element)
      let se = self.southEast!.remove(element)

      return nw || ne || sw || se
    }
  }

  // MARK: - Private

  /// Keeping a reference to the parent so we can search nearby quads
  /// and unsubdivide after deletion.
  private var parent: BMQuadtree? {
    didSet {
      self.depth = parent!.depth + 1
    }
  }

  /// The number of objects stored in the cell
  private var minCellSize: Float = 1

  /// Objects stored in this node
  private var objects: [Object] = []

  /// True, if the tree has leafs.
  /// It means, there are no objects stored direclty in the tree, but only
  /// in its leafs.
  internal var hasQuads: Bool {
    return self.northWest != nil
  }

  /**
   * Removes the given NSObject from the given quadtree node
   * Note that this is not an exhaustive search and is faster than removeData:
   *
   * @param element the element to be removed
   * @param node the node in which this data resides
   * @return returns YES if the data was removed, NO otherwise
   */
//  open func remove(_ data: ElementType, using node: GKQuadtreeNode) -> Bool

  /// Function to subdivide a QuadTree into 4 smaller QuadTrees
  private func subdivide() {

    let minX = self.quad.quadMin.x
    let minY = self.quad.quadMin.y
    let maxX = self.quad.quadMax.x
    let maxY = self.quad.quadMax.y

    let deltaX = maxX - minX
    let deltaY = maxY - minY

    let quadNW = GKQuad(
      quadMin: float2(minX, minY + deltaY / 2),
      quadMax: float2(maxX - deltaX / 2, maxY))

    let quadNE = GKQuad(
      quadMin: float2(minX + deltaX / 2, minY + deltaY / 2),
      quadMax: float2(maxX, maxY))

    let quadSW = GKQuad(
      quadMin: float2(minX, minY),
      quadMax: float2(minX + deltaX / 2, minY + deltaY / 2))

    let quadSE = GKQuad(
      quadMin: float2(minX + deltaX / 2, minY),
      quadMax: float2(maxX, maxY - deltaY / 2))

    self.northWest = BMQuadtree(
      boundingQuad: quadNW,
      minimumCellSize: self.minCellSize)
    self.northWest?.parent = self

    self.northEast = BMQuadtree(
      boundingQuad: quadNE,
      minimumCellSize: self.minCellSize)
    self.northEast?.parent = self

    self.southWest = BMQuadtree(
      boundingQuad: quadSW,
      minimumCellSize: self.minCellSize)
    self.southWest?.parent = self

    self.southEast = BMQuadtree(
      boundingQuad: quadSE,
      minimumCellSize: self.minCellSize)
    self.southEast?.parent = self
  }

  /// Optimising the quadtree by cleanin up after removing elements.
  /// If the number of elements in all subquads are less then minimumCellSize,
  /// delete all the sub-quads and place the objects into the parent.
  private func unify() {
    // If all guads are empty, delete them all
    if self.northWest?.objects.count == 0 &&
      self.northEast?.objects.count == 0 &&
      self.southWest?.objects.count == 0 &&
      self.southEast?.objects.count == 0 {
        self.northWest = nil
        self.northEast = nil
        self.southWest = nil
        self.southEast = nil
    }

    // BMTODO: Collect all elements in sub-quads and place them in self instead
    // if collective object count in sub-quads is less then minimumCellSize

  }
}
