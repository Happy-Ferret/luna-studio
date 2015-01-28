---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}

module Flowbox.Graphics.Shader.Stencil where

import Flowbox.Graphics.Shader.Shader
import Flowbox.Math.Matrix            as M hiding (get, stencil)
import Flowbox.Prelude                as P hiding (filter)

import qualified Data.Array.Accelerate     as A
import           Math.Coordinate.Cartesian (Point2 (..))
import           Math.Space.Space          hiding (height, width)



stencil :: forall a b c . (Elt a, IsNum a)
        => (Point2 c -> Point2 (Exp Int) -> Point2 b)
        -> DiscreteShader (Exp a) -- kernel generator
        -> (Exp a -> Exp a -> Exp a) -> Exp a
        -> CartesianShader b (Exp a) -> CartesianShader c (Exp a)
stencil mode (Shader (Grid width height) kernel) foldOp initVal (Shader cnv input) = Shader cnv $ \pos ->
    let get x' y' = input $ mode pos (Point2 x' y')
        outer :: (Exp Int, Exp a) -> (Exp Int, Exp a)
        outer (h, acc) = (h + 1, A.snd $ A.while (\e -> A.fst e A.<* width) (A.lift1 inner) (A.lift (0 :: Exp Int, acc)))
            where inner :: (Exp Int, Exp a) -> (Exp Int, Exp a)
                  inner (w, acc') = (w + 1, acc' `foldOp` (kernel (Point2 w h) * get (w - width `div` 2) (h - height `div` 2)))
    in A.snd $ A.while (\e -> A.fst e A.<* height) (A.lift1 outer) (A.lift (0 :: Exp Int, initVal))

bilateralStencil :: forall a b c . (Elt a, IsNum a, IsFloating a)
            => (Point2 c -> Point2 (Exp Int) -> Point2 b)
            -> DiscreteShader (Exp a) -- spatial kernel generator
            -> (Exp a -> Exp a -> Exp a) -- domain kernel
            -> (Exp a -> Exp a -> Exp a) -> Exp a
            -> CartesianShader b (Exp a) -> CartesianShader c (Exp a)
bilateralStencil mode (Shader (Grid width height) kernel) domain foldOp _initVal (Shader cnv input) = Shader cnv $ \pos ->
    let get x' y' = input $ mode pos (Point2 x' y')

        testW :: (Exp Int, Exp a, Exp a) -> Exp Bool
        testW (e, _, _) = e A.<=* width

        testH :: (Exp Int, Exp a, Exp a) -> Exp Bool
        testH (e, _, _) = e A.<=* height

        start :: Exp a -> Exp a -> Exp (Int, a, a)
        start val wei = A.lift (0 :: Exp Int, val :: Exp a, wei :: Exp a)

        outer :: (Exp Int, Exp a, Exp a) -> (Exp Int, Exp a, Exp a)
        outer (h, accV, accW) = (h + 1, resV, resW)
            where (_ :: Exp Int, resV :: Exp a, resW :: Exp a) = A.unlift $ A.while (A.lift1 testW) (A.lift1 inner) (start accV accW)
                  inner :: (Exp Int, Exp a, Exp a) -> (Exp Int, Exp a, Exp a)
                  inner (w, accV', accW') = (w + 1, accV' `foldOp` (weight * value), accW' + weight)
                      where weight = domain (get 0 0) value * kernel (Point2 w h)
                            value = get (w - width `div` 2) (h - height `div` 2)
        (_ :: Exp Int, valueSum :: Exp a, weightSum :: Exp a) = A.unlift $ A.while (A.lift1 testH) (A.lift1 outer) (start 0 0)
        --                                                                                                     FIXME[mm]: ^ initVal nie powinno być tu?
    in valueSum / weightSum

normStencil :: forall a b c . (Elt a, IsNum a, IsFloating a)
            => (Point2 c -> Point2 (Exp Int) -> Point2 b)
            -> DiscreteShader (Exp a) -- spatial kernel generator
            -> (Exp a -> Exp a -> Exp a) -> Exp a
            -> CartesianShader b (Exp a) -> CartesianShader c (Exp a)
normStencil mode gen = bilateralStencil mode gen $ \_ _ -> 1
