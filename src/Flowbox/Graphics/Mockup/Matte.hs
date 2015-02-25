---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE TypeFamilies  #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns  #-}

module Flowbox.Graphics.Mockup.Matte (
    Matte,
    applyMatteFloat,
    imageMatteLuna,
    rasterizeMaskLuna,
    vectorMatteLuna,
) where

import qualified Data.Array.Accelerate     as A
import           Data.RTuple               (RTuple (RTuple), toTuple)
import           Math.Coordinate.Cartesian (Point2 (..))
import           Math.Space.Space          (Grid (..))
import qualified System.FilePath           as FilePath

import           Flowbox.Geom2D.ControlPoint
import qualified Flowbox.Geom2D.Mask            as Mask
import           Flowbox.Geom2D.Path
import           Flowbox.Geom2D.Rasterizer
import qualified Flowbox.Geom2D.Shape           as GShape
import           Flowbox.Graphics.Image.Channel (Channel (..), ChannelData (..))
import           Flowbox.Graphics.Image.Image   (Image)
import           Flowbox.Graphics.Image.Matte   (Matte)
import qualified Flowbox.Graphics.Image.Matte   as Matte
import           Flowbox.Graphics.Mockup.Basic
import           Flowbox.Graphics.Shader.Shader (CartesianShader, Shader (..))
import qualified Flowbox.Graphics.Shader.Shader as Shader
import           Flowbox.Math.Matrix            (Matrix2)
import qualified Flowbox.Math.Matrix            as M
import           Flowbox.Prelude                as P
import           Luna.Target.HS.Host.Lift       (expandEl)



type ControlPoint2 a = RTuple (  VPS (Point2 a)
                              , (VPS (Maybe (Point2 a))
                              , (VPS (Maybe (Point2 a))
                              , ())))

type Path2 a = RTuple (  VPS Bool
                      , (VPS [VPS (ControlPoint2 a)]
                      , ()))

type Path2x a = RTuple ( Bool
                      , ([VPS (ControlPoint2 a)]
                      , ()))

type Shape2 a = [VPS (Path2 a)]

type Mask2 a = RTuple (  VPS (Path2 a)
                      , (VPS (Maybe (Path2x a))
                      , ()))

convertControlPoint :: ControlPoint2 a -> ControlPoint a
convertControlPoint (toTuple -> (unpackLunaVar -> a, unpackLunaVar -> b, unpackLunaVar -> c)) = ControlPoint a b c

convertPath :: Path2 a -> Path a
convertPath (toTuple -> (unpackLunaVar -> a, unpackLunaList.unpackLunaVar -> b)) = Path a (fmap convertControlPoint b)

convertShape :: Shape2 a -> GShape.Shape a
convertShape (unpackLunaList -> a) = GShape.Shape (fmap convertPath a)

convertMask :: Mask2 a -> Mask.Mask a
convertMask (toTuple -> (unpackLunaVar -> a, unpackLunaVar -> (fmap expandEl) -> b)) = Mask.Mask (convertPath a) (fmap convertPath b)

rasterizeMaskLuna :: (Real a, Fractional a, a ~ Float) => Int -> Int -> Mask2 a -> Image
rasterizeMaskLuna w h (convertMask -> m) = matrixToImage $ rasterizeMask w h m

imageMatteLuna :: Image -> String -> Maybe (Matte Float)
imageMatteLuna img channelName =
  let channel = getChannelFromPrimaryLuna channelName img
  in
    case channel of
      Right (Just channel) -> Just $ Matte.imageMatteFloat channel
      _ -> Nothing

vectorMatteLuna :: Mask2 Float -> Maybe (Matte Float)
vectorMatteLuna mask = Just $ Matte.VectorMatte $ convertMask mask

adjustMatte :: Matrix2 Float -> Matrix2 Float -> Matrix2 Float
adjustMatte mat matte = matte'
  where
    sh = M.shape matte
    A.Z A.:. h A.:. w = A.unlift sh :: A.Z A.:. (A.Exp Int) A.:. (A.Exp Int)

    matte' = M.generate (M.shape mat) (\sh ->
      let
        A.Z A.:. x A.:. y = A.unlift sh :: A.Z A.:. (A.Exp Int) A.:. (A.Exp Int)
      in
        (x A.<* h A.&&* y A.<* w) A.? (matte M.! sh, 0.0))

applyMatteFloat :: (A.Exp Float -> A.Exp Float) -> Matte Float -> Channel -> Channel
applyMatteFloat f m (ChannelFloat name (MatrixData mat)) = ChannelFloat name (MatrixData mat')
  where
    sh = M.shape mat
    A.Z A.:. x A.:. y = A.unlift sh :: A.Z A.:. (A.Exp Int) A.:. (A.Exp Int)
    (h,w) = unpackAccDims (x,y)
    matte = Matte.matteToMatrix h w m
    mat' = applyToMatrix f (adjustMatte mat matte) mat

applyMatteFloat f m (ChannelFloat name (DiscreteData shader)) = ChannelFloat name (DiscreteData shader')
  where
    Shader (Grid h' w') _ = shader
    (h,w) = unpackAccDims (h',w')
    matte = Matte.matteToDiscrete h w m
    shader' = applyToShader f matte shader

applyMatteFloat f m (ChannelFloat name (ContinuousData shader)) = ChannelFloat name (ContinuousData shader')
  where
    Shader (Grid h' w') _ = shader
    (h,w) = unpackAccDims (h',w')
    matte = Matte.matteToContinuous h w m
    shader' = applyToShader f matte shader

-- looks strange, but is necessary because of the weird accelerate behaviour
maskedApp :: (A.IsNum a, A.Elt a) => (A.Exp a -> A.Exp a) -> A.Exp a -> A.Exp a -> A.Exp a
maskedApp f a b = (a A.==* 0) A.? (b,b + a*(delta f b))
-- won't work, no idea what is the reason of that
--aux a b f = b + a*(delta f b)
  where
    delta :: (A.IsNum a, A.Elt a) => (A.Exp a -> A.Exp a) -> (A.Exp a) -> (A.Exp a)
    delta f x = (f x) - x

applyToShader :: (A.IsNum b, A.Elt a, A.Elt b) => (A.Exp b -> A.Exp b) -> CartesianShader (A.Exp a) (A.Exp b) -> CartesianShader (A.Exp a) (A.Exp b) -> CartesianShader (A.Exp a) (A.Exp b)
applyToShader f matte mat = Shader.combineWith (maskedApp f) matte mat

applyToMatrix :: (A.IsNum a, A.Elt a) => (A.Exp a -> A.Exp a) -> Matrix2 a -> Matrix2 a -> Matrix2 a
applyToMatrix f matte mat = (M.zipWith (\x -> \y -> (maskedApp f x y)) matte) mat
