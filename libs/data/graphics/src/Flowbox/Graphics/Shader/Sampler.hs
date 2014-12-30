---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Flowbox.Graphics.Composition.Generators.Sampler where

import Flowbox.Graphics.Composition.Generators.Structures
import Flowbox.Graphics.Composition.Generators.Filter     (Filter(..), convolve)
import Flowbox.Graphics.Utils
import Flowbox.Math.Matrix                                as M hiding (get, size)
import Flowbox.Prelude                                    as P hiding (filter, transform)

import qualified Data.Array.Accelerate     as A
import           Math.Coordinate.Cartesian (Point2(..))



type Sampler e = ContinousGenerator (Exp e) -> DiscreteGenerator (Exp e)

monosampler :: (Elt a, IsNum a) => CartesianGenerator (Exp a) e -> DiscreteGenerator e
monosampler = transform $ fmap A.fromIntegral

multisampler :: (Elt e, IsNum e, IsFloating e) => Matrix2 e -> CartesianGenerator (Exp e) (Exp e) -> DiscreteGenerator (Exp e)
multisampler kernel = convolve msampler kernel
    where fi = fmap A.fromIntegral
          msampler point offset = fi point + subpixel * fi offset
          Z :. h :. w = A.unlift $ shape kernel
          subpixel = Point2 (1 / (A.fromIntegral w - 1)) (1 / (A.fromIntegral h - 1))

nearest :: (Elt e, IsFloating e) => DiscreteGenerator (Exp e) -> CartesianGenerator (Exp e) (Exp e)
nearest = transform $ fmap A.floor

interpolator :: forall e . (Elt e, IsFloating e) => Filter (Exp e) -> DiscreteGenerator (Exp e) -> CartesianGenerator (Exp e) (Exp e)
interpolator filter (Generator cnv input) = Generator cnv $ \pos@(Point2 x y) ->
    let get x' y' = input $ fmap A.floor pos + Point2 x' y'
        size = A.floor $ window filter
        kernel dx dy = apply filter (A.fromIntegral dx - frac x) * apply filter (A.fromIntegral dy - frac y)

        test :: (Exp Int, Exp e, Exp e) -> Exp Bool
        test (e, _, _) = e A.<=* size

        start :: Exp e -> Exp e -> Exp (Int, e, e)
        start val wei = A.lift (-size :: Exp Int, val :: Exp e, wei :: Exp e)

        outer :: (Exp Int, Exp e, Exp e) -> (Exp Int, Exp e, Exp e)
        outer (h, accV, accW) = (h + 1, resV, resW)
            where (_ :: Exp Int, resV :: Exp e, resW :: Exp e) = A.unlift $ A.while (A.lift1 test) (A.lift1 inner) (start accV accW)
                  inner :: (Exp Int, Exp e, Exp e) -> (Exp Int, Exp e, Exp e)
                  inner (w, accV, accW) = (w + 1, accV + kernel w h * get w h, accW + kernel w h)
        (_ :: Exp Int, valueSum :: Exp e, weightSum :: Exp e) = A.unlift $ A.while (A.lift1 test) (A.lift1 outer) (start 0 0)
    in valueSum / weightSum
