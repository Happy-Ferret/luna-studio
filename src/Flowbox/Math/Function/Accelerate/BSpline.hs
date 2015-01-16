---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns #-}

module Flowbox.Math.Function.Accelerate.BSpline where

import           Data.Array.Accelerate as A
import           Data.Array.Accelerate.Smart
import           Data.Array.Accelerate.Tuple
import           Data.Array.Accelerate.Array.Sugar
import           Data.Typeable

import Math.Coordinate.Cartesian                   (Point2(..))
import Flowbox.Geom2D.CubicBezier
import Flowbox.Geom2D.Accelerate.CubicBezier       ()
import Flowbox.Geom2D.Accelerate.CubicBezier.Solve
import Flowbox.Prelude                             hiding (lift, (!!), (?), (<*), fst, snd)



data BSplineNode a = BSplineNode { node      :: Point2 a
                                 , handleIn  :: Point2 a
                                 , handleOut :: Point2 a
                                 } deriving (Eq, Ord, Show,Typeable)
type BSpline a = Vector (BSplineNode a)

instance Functor BSplineNode where
    fmap f (BSplineNode a b c) = BSplineNode (fmap f a) (fmap f b) (fmap f c)

instance Applicative BSplineNode where
    pure a = BSplineNode (pure a) (pure a) (pure a)
    {-# INLINE pure #-}
    BSplineNode a b c <*> BSplineNode e f g = BSplineNode (a <*> e) (b <*> f) (c <*> g)
    {-# INLINE (<*>) #-}

valueAt :: forall a. (Elt a, IsFloating a) => Acc (BSpline a) -> Exp a -> Exp a
valueAt spline x = cond (sLength <* 1) 0
    $ cond (x <* xL) lineA $ cond (x >* xR) lineB
        $ snd $ while (\(fst -> v) -> fst v <* sLength - 1 &&* snd v <* x) (lift1 step) $ lift (lift (0 :: Exp Int, xL) :: Exp (Int, a), yL :: Exp a)
    where (unlift -> BSplineNode (Point2 xL yL) (Point2 xHiL yHiL) _) = spline !! 0
          (unlift -> BSplineNode (Point2 xR yR) _ (Point2 xHoR yHoR)) = spline !! (sLength - 1)
          step :: (Exp (Int, a), Exp a) -> (Exp (Int, a), Exp a)
          step (unlift -> (i :: Exp Int, _ :: Exp a), _) = let
                            (unlift -> BSplineNode nodeA _ handleOutA) = spline !! i
                            (unlift -> BSplineNode nodeB@(Point2 xR' _) handleInB _) = spline !! (i + 1)
                        in (lift (i+1, xR'), valueAtX 10 0.001 (lift $ CubicBezier nodeA handleOutA handleInB nodeB) x)
          -- INFO: if the left handle of the first node is `vertical / of length equal to 0` then the function from -Inf to the first node is treaded as a constant function
          --       the similar rule applies to the right handle of the last node and range from the last node to Inf
          sLength = A.size spline
          lineA   = lineValue xL yL xHiL yHiL
          lineB   = lineValue xR yR xHoR yHoR
          lineValue xA yA xB yB = let
                  a = (yB - yA) / (xB - xA)
                  b = yA - a * xA
              in xA ==* xB ? (yA, a * x + b)

----------------------------------------------------------------------------------
---- BSplineNode accelerate tuple instances # straight to the tuple with no intermediate (un)lifting
----------------------------------------------------------------------------------
type instance EltRepr (BSplineNode a)  = EltRepr ((a, a), (a, a), (a, a))
type instance EltRepr' (BSplineNode a) = EltRepr' ((a, a), (a, a), (a, a))

instance Elt a => Elt (BSplineNode a) where
  eltType _ = eltType (undefined :: ((a,a),(a,a),(a,a)))
  toElt n = case toElt n of
     ((a, b), (c, d), (e, f)) -> BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)
  fromElt (BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)) = fromElt ((a, b), (c, d), (e, f))

  eltType' _ = eltType' (undefined :: ((a,a),(a,a),(a,a)))
  toElt' n = case toElt' n of
     ((a, b), (c, d), (e, f)) -> BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)
  fromElt' (BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)) = fromElt' ((a, b), (c, d), (e, f))

instance IsTuple (BSplineNode a) where
  type TupleRepr (BSplineNode a) = TupleRepr ((a,a),(a,a),(a,a))
  fromTuple (BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)) = fromTuple ((a, b), (c, d), (e, f))
  toTuple t = case toTuple t of
     ((a, b), (c, d), (e, f)) -> BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)

instance (Lift Exp a, Elt (Plain a)) => Lift Exp (BSplineNode a) where
  type Plain (BSplineNode a) = BSplineNode (Plain a)
  --  lift = Exp . Tuple . F.foldl SnocTup NilTup
  lift (BSplineNode (Point2 a b) (Point2 c d) (Point2 e f)) =
    Exp $ Tuple $ NilTup `SnocTup`
    (Exp $ Tuple $ NilTup `SnocTup` lift a `SnocTup` lift b)
     `SnocTup`
    (Exp $ Tuple $ NilTup `SnocTup` lift c `SnocTup` lift d)
    `SnocTup`
    (Exp $ Tuple $ NilTup `SnocTup` lift e `SnocTup` lift f)

instance (Elt a, e ~ Exp a) => Unlift Exp (BSplineNode e) where
  unlift t = let
    p1 = Exp $ SuccTupIdx (SuccTupIdx ZeroTupIdx) `Prj` t
    p2 = Exp $ SuccTupIdx ZeroTupIdx `Prj` t
    p3 = Exp $ ZeroTupIdx `Prj` t
    in BSplineNode
      (Point2 (Exp $ SuccTupIdx ZeroTupIdx `Prj` p1) (Exp $ ZeroTupIdx `Prj` p1))
      (Point2 (Exp $ SuccTupIdx ZeroTupIdx `Prj` p2) (Exp $ ZeroTupIdx `Prj` p2))
      (Point2 (Exp $ SuccTupIdx ZeroTupIdx `Prj` p3) (Exp $ ZeroTupIdx `Prj` p3))
