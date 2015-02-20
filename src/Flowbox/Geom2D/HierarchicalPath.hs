{-# LANGUAGE TemplateHaskell #-}
module Flowbox.Geom2D.HierarchicalPath where

import qualified Flowbox.Geom2D.ControlPoint            as C
import qualified Flowbox.Geom2D.Path                    as P
import qualified Flowbox.Geom2D.Mask                    as M
import           Flowbox.Prelude                        as P
import qualified Flowbox.Graphics.Composition.Transform as Transform

import           Linear                                 (V2 (..))
import           Math.Coordinate.Cartesian
import           Data.IntMap                            as I
import           Data.Vector                            as V
import           Data.Vector.Mutable                    as MV
import           Data.Maybe
import           Control.Monad.ST
import           Control.Monad                          as C
import           Data.STRef
import           Data.List                              as L

type Rank      = Int
type Angles a  = (a, a)
type Handles a = (V2 a, V2 a)

data ControlPoint a = BasePoint      { _coords  :: Point2 a
                                     , _handles :: Handles a
                                     }
                    | DependentPoint { _rank    :: Rank
                                     , _angles  :: Angles a
                                     , _handles :: Handles a
                                     } deriving (Eq, Ord, Show)

makeLenses ''ControlPoint

data Path a = Path { isClosed      :: Bool
                   , controlPoints :: [ControlPoint a]
                   } deriving (Eq, Ord, Show)

data OrdinaryControlPoint a = OrdinaryControlPoint { controlPoint :: Point2 a
                                   , handleIn     :: Maybe (Point2 a)
                                   , handleOut    :: Maybe (Point2 a)
                                   } deriving (Eq, Ord, Show)

type Parents = (Maybe Int, Maybe Int)

convert :: (Fractional a, Floating a) => [ControlPoint a] -> [OrdinaryControlPoint a]
convert points = P.map convertEl $ P.zip coords points
  where
    ranks   = P.map extract points
    parents = makeTree ranks
    order   = P.map (\(_,y) -> y) $ L.sort $ P.zip ranks [0..]
    coords  = walk (V.fromList points) parents order

    convertEl :: (Fractional a, Floating a) => (Point2 a, ControlPoint a) -> OrdinaryControlPoint a
    convertEl (center, cPoint) = absCoords center cPoint
      where
        absCoords :: (Fractional a, Floating a) => Point2 a -> ControlPoint a -> OrdinaryControlPoint a
        absCoords center p = OrdinaryControlPoint center (Just (Transform.translate h1 center)) (Just (Transform.translate h2 center))
          where
            (h1, h2) = p ^. handles

    extract :: ControlPoint a -> Int
    extract x = 
      case x of
        BasePoint _ _ -> 0
        DependentPoint r _ _ -> r

walk :: (Fractional a, Floating a) => Vector (ControlPoint a) -> IntMap Parents -> [Int] -> [Point2 a]
walk points parents order = P.map (\(_,y) -> y) $ I.toList $ aux order coords
  where
    coords = I.empty :: IntMap (Point2 a)

    aux [] coords = coords
    aux (idx:l) coords = 
      case p of
        DependentPoint _ ang (h1,h2) -> let (Just p1, Just p2) = parents I.! idx
                                        in
                                          aux l (I.insert idx (computeCoords (coords I.! p1) (coords I.! p2) ang) coords)
        BasePoint c (h1,h2) -> aux l (I.insert idx c coords)
      where
        p = points V.! idx

computeCoords :: (Fractional a, Floating a) => Point2 a -> Point2 a -> Angles a -> Point2 a
computeCoords p1@(Point2 x1 y1) p2@(Point2 x2 y2) (ang1, ang2) = Transform.rotate ang1 (movePoint p1 p2 ratio)
  where
    ang = pi - ang1 - ang2
    c = segLength p1 p2
    b = c * (sin ang2) / (sin ang)
    ratio = b / c

    segLength :: (Fractional a, Floating a) => Point2 a -> Point2 a -> a
    segLength (Point2 x1 y1) (Point2 x2 y2) = sqrt(l)
      where
        l = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)

    movePoint :: (Fractional a, Floating a) => Point2 a -> Point2 a -> a -> Point2 a
    movePoint (Point2 x1 y1) (Point2 x2 y2) t = (Point2 (x1 - (x1 - x2) * t) (y1 - (y1 - y2) * t))

makeTree :: [Int] -> IntMap Parents
makeTree ranks = aux 0 (ranks P.++ ranks) stacks pred (I.fromList $ genList (Nothing, Nothing) len)
    where
        aux :: Int -> [Int] -> IntMap [Int] -> IntMap (Maybe Int) -> IntMap Parents -> IntMap Parents
        aux idx [] stacks pred acc = acc
        aux idx (rank:l) stacks pred acc =
            case rank of
                0 -> aux (idx+1) l stacks' pred' acc'
                _ -> let
                        (left,right) = acc I.! idx'
                        left'        = pred I.! (rank-1)
                        acc''         = I.insert idx' (left',right) acc'
                     in
                        aux (idx+1) l stacks' pred' acc''
            where 
                idx'           = idx `mod` len
                pred'          = I.insert rank (Just idx') pred
                deps           = stacks I.! (rank+1)
                stacks'        = I.insert (rank+1) ([]) $ I.adjust (\x -> (idx':x)) rank stacks
                acc'           = updateDeps idx' deps acc

                updateDeps :: Int -> [Int] -> IntMap Parents -> IntMap Parents
                updateDeps idx [] acc = acc
                updateDeps idx (a:l) acc = updateDeps idx l acc'
                    where
                        (left,right) = acc I.! a
                        acc' = I.insert a (left, Just idx) acc

        len    = P.length ranks
        stacks = I.fromList $ genList ([]) (maxRank+2)
        pred   = I.fromList $ genList (Nothing) (maxRank+2)
        maxRank = P.maximum ranks

        genList :: a -> Int -> [(Int,a)]
        genList v len = P.take len $ P.map (\x -> (x, v)) $ P.iterate (+1) 0