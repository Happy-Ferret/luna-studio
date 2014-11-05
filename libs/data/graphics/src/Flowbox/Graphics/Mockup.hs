---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE PatternSynonyms           #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeOperators             #-}
{-# LANGUAGE ViewPatterns              #-}

module Flowbox.Graphics.Mockup (
      module Flowbox.Graphics.Mockup
    , module Math.Metric
    , A.Boundary(..)
) where

import qualified Codec.Picture.Png                 as Juicy
import qualified Codec.Picture.Types               as Juicy
import qualified Data.Array.Accelerate             as A
import qualified Data.Array.Accelerate.Array.Sugar as A
import           Data.Array.Accelerate.CUDA
import qualified Data.Array.Accelerate.IO          as A
import           Data.Char                         (toLower)
import qualified Data.Vector.Storable              as SV
import           Math.Coordinate.Cartesian
import           Math.Space.Space
import           Math.Metric
import           Linear                            (V2(..))

import qualified Flowbox.Graphics.Color                               as Color
import           Flowbox.Graphics.Composition.Dither
import           Flowbox.Graphics.Composition.Generators.Filter
import           Flowbox.Graphics.Composition.Generators.Filter       as Conv
import           Flowbox.Graphics.Composition.Generators.Gradient
import           Flowbox.Graphics.Composition.Generators.Keyer
import           Flowbox.Graphics.Composition.Generators.Matrix
import           Flowbox.Graphics.Composition.Generators.Noise.Billow
import           Flowbox.Graphics.Composition.Generators.Noise.Perlin
import           Flowbox.Graphics.Composition.Generators.Pipe
import           Flowbox.Graphics.Composition.Generators.Rasterizer
import           Flowbox.Graphics.Composition.Generators.Sampler
import           Flowbox.Graphics.Composition.Generators.Shape
import           Flowbox.Graphics.Composition.Generators.Stencil
import           Flowbox.Graphics.Composition.Generators.Structures
import           Flowbox.Graphics.Composition.Generators.Transform
import           Flowbox.Graphics.Composition.Histogram
import           Flowbox.Graphics.Image.Channel
import           Flowbox.Graphics.Image.Color
import           Flowbox.Graphics.Image.Image                         as Image
import           Flowbox.Graphics.Image.IO.ImageMagick                (loadImage, saveImage)
import           Flowbox.Graphics.Image.Merge                         (AlphaBlend(..))
import qualified Flowbox.Graphics.Image.Merge                         as Merge
import           Flowbox.Graphics.Image.View                          as View
import           Flowbox.Graphics.Utils
import           Flowbox.Math.Matrix                                  as M
import           Flowbox.Prelude                                      as P hiding (lookup)

import Luna.Target.HS (Pure (..), Safe (..), Value (..), autoLift, autoLift1, fromValue, val)
import Control.PolyApplicative ((<<*>>))



testLoadRGBA' :: Value Pure Safe String -> Value IO Safe (Value Pure Safe (Matrix2 Double), Value Pure Safe (Matrix2 Double), Value Pure Safe (Matrix2 Double), Value Pure Safe (Matrix2 Double))
testLoadRGBA' path = autoLift1 ((fmap.fmap) (over each val) $ testLoadRGBA) path

testLoadRGBA :: FilePath -> IO (Matrix2 Double, Matrix2 Double, Matrix2 Double, Matrix2 Double)
testLoadRGBA filename = do
    file <- loadImage filename
    case file of
        Right mat -> return $ M.unzip4 $ M.map (convert . A.unpackRGBA32) (Raw mat)
        Left e -> error $ "Unable to load file: " P.++ show e
    where convert t = let (r, g, b, a) = A.unlift t :: (A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8)
                      in A.lift (A.fromIntegral r / 255, A.fromIntegral g / 255, A.fromIntegral b / 255, A.fromIntegral a / 255)

testSaveRGBA :: FilePath -> Matrix2 Double -> Matrix2 Double -> Matrix2 Double -> Matrix2 Double -> IO ()
testSaveRGBA filename r g b a = saveImageJuicy filename $ compute' run $ M.map A.packRGBA32 $ M.zip4 (conv r) (conv g) (conv b) (conv a)
    where conv = M.map (A.truncate . (* 255.0) . clamp' 0 1)

saveImageJuicy :: forall e a.
                        (SV.Storable a, Elt e,
                         A.Vectors (A.EltRepr e)
                         ~ ((), SV.Vector a)) =>
                        FilePath -> A.Array ((Z :. Int) :. Int) e -> IO ()
saveImageJuicy file matrix = do
    let ((), vec) = A.toVectors matrix
        A.Z A.:. h A.:. w = A.arrayShape matrix
    Juicy.writePng file $ (Juicy.Image w h (SV.unsafeCast vec) :: Juicy.Image Juicy.PixelRGBA8)

pattern VPS x = Value (Pure (Safe x))
type VPS x = Value Pure Safe x

defocus :: VPS Int -> Matrix2 Double -> Matrix2 Double
defocus (VPS size) = process
    where kernel = ellipse (pure $ variable size) 1 (0 :: A.Exp Double)
          process = rasterizer . normStencil (+) kernel (+) 0 . fromMatrix A.Clamp

motionBlur :: VPS Int -> VPS Double -> Matrix2 Double -> Matrix2 Double
motionBlur (VPS size) (VPS angle) = process
    where kernel = monosampler
                 $ rotateCenter (variable angle)
                 $ nearest
                 $ rectangle (Grid (variable size) 1) 1 0
          process = rasterizer . normStencil (+) kernel (+) 0 . fromMatrix A.Clamp

-- rotateCenter :: (Elt a, IsFloating a) => Exp a -> CartesianGenerator (Exp a) b -> CartesianGenerator (Exp a) b
rotateCenter phi = canvasT (fmap A.ceiling . rotate phi . asFloating) . onCenter (rotate phi)

bilateral :: VPS Double
          -> VPS Double
          -> VPS Int
          -> Matrix2 Double
          -> Matrix2 Double
bilateral (VPS psigma) (VPS csigma) (VPS (variable -> size)) = process
    where p = pipe A.Clamp
          spatial :: Generator (Point2 (Exp Int)) (Exp Double)
          spatial = Generator (pure $ variable size) $ \(Point2 x y) ->
              let dst = sqrt . A.fromIntegral $ (x - size `div` 2) * (x - size `div` 2) + (y - size `div` 2) * (y - size `div` 2)
              in apply (gauss $ variable psigma) dst
          domain center neighbour = apply (gauss $ variable csigma) (abs $ neighbour - center)
          process = rasterizer . (id `p` bilateralStencil (+) spatial domain (+) 0 `p` id) . fromMatrix A.Clamp

offsetLuna :: VPS Double -> A.Exp Double -> A.Exp Double
offsetLuna (VPS (variable -> v)) = offset v

contrastLuna :: VPS Double -> A.Exp Double -> A.Exp Double
contrastLuna (VPS (variable -> v)) = contrast v

exposureLuna :: VPS Double -> VPS Double -> A.Exp Double -> A.Exp Double
exposureLuna (VPS (variable -> blackpoint)) (VPS (variable -> ex)) = exposure blackpoint ex

colorCorrectLuna :: VPS Double -> VPS Double -> VPS Double -> VPS Double -> VPS Double -> A.Exp (Color.RGB Double) -> A.Exp (Color.RGB Double)
colorCorrectLuna (VPS (variable -> saturation'))
                 (VPS (variable -> contrast'))
                 (VPS (variable -> gamma'))
                 (VPS (variable -> gain'))
                 (VPS (variable -> offset')) =
                    colorCorrect saturation' contrast' gamma' gain' offset'

gradeLuna :: VPS Double -> VPS Double -> VPS Double -> VPS Double -> VPS Double -> VPS Double -> VPS Double -> A.Exp Double -> A.Exp Double
gradeLuna (VPS (variable -> blackpoint))
          (VPS (variable -> whitepoint))
          (VPS (variable -> lift))
          (VPS (variable -> gain))
          (VPS (variable -> multiply'))
          (VPS (variable -> offset'))
          (VPS (variable -> gamma')) =
            grade blackpoint whitepoint lift gain multiply' offset' gamma'

saturateLuna :: VPS Double -> A.Exp (Color.RGB Double) -> A.Exp (Color.RGB Double)
saturateLuna (VPS (variable -> s)) = A.lift1 $ (saturate s :: Color.RGB (A.Exp Double) -> Color.RGB (A.Exp Double))

posterizeLuna :: VPS Double -> A.Exp Double -> A.Exp Double
posterizeLuna (VPS (variable -> colors)) = posterize colors

loadImageLuna :: FilePath -> IO (Image RGBA)
loadImageLuna path = do
    (r, g, b, a) <- testLoadRGBA path
    let view = View.empty "rgba"
             & View.append (ChannelFloat "r" . FlatData $ r)
             & View.append (ChannelFloat "g" . FlatData $ g)
             & View.append (ChannelFloat "b" . FlatData $ b)
             & View.append (ChannelFloat "a" . FlatData $ a)
        image = singleton view
    return image

saveImageLuna :: FilePath -> Image RGBA -> IO (Image RGBA)
saveImageLuna path img = do
    let (r, g, b, a) = unsafeGetChannels img
    testSaveRGBA path r g b a
    return img

onEachChannel :: (Matrix2 Double -> Matrix2 Double) -> Image RGBA -> Image RGBA
onEachChannel f img = res
    where res = Image.map (View.map fChan) img
          fChan :: Channel -> Channel
          fChan (ChannelFloat name flatdata) = ChannelFloat name (flatdata & matrix %~ f)

onEachValue :: (A.Exp Double -> A.Exp Double) -> Image RGBA -> Image RGBA
onEachValue f img = res
    where res = Image.map (View.map f') img

          f' :: Channel -> Channel
          f' (ChannelFloat name flatdata) = ChannelFloat name (flatdata & matrix %~ (M.map f))

onEachRGB :: (A.Exp (Color.RGB Double) -> A.Exp (Color.RGB Double)) -> Image RGBA -> Image RGBA
onEachRGB f img = img'
    where rgb = unsafeGetRGB img
          Just view = lookup "rgba" img
          rgb' = M.map f rgb

          unzipRGB = M.unzip3 . M.map (\(A.unlift -> Color.RGB x y z) -> A.lift (x, y, z))

          (r', g', b') = unzipRGB rgb'

          view' = view
                & View.append (ChannelFloat "r" (FlatData r'))
                & View.append (ChannelFloat "g" (FlatData g'))
                & View.append (ChannelFloat "b" (FlatData b'))

          Right img' = Image.update (const $ Just view') "rgba" img

keyer' :: (A.Exp (Color.RGB Double) -> A.Exp Double) -> Image RGBA -> Image RGBA
keyer' f img = img'
    where rgb = unsafeGetRGB img
          Just view = lookup "rgba" img
          alpha = M.map f rgb

          view' = View.append (ChannelFloat "a" (FlatData alpha)) view

          Right img' = Image.update (const $ Just view') "rgba" img

unsafeGetRGB :: Image RGBA -> M.Matrix2 (Color.RGB Double)
unsafeGetRGB img = rgb
    where (r, g, b, _) = unsafeGetChannels img

          rgb = M.zipWith3 (\x y z -> A.lift $ Color.RGB x y z) r g b

unsafeGetChannels :: Image RGBA -> (M.Matrix2 Double, M.Matrix2 Double, M.Matrix2 Double, M.Matrix2 Double)
unsafeGetChannels img = (r, g, b, a)
    where Just view = lookup "rgba" img
          Right (Just (ChannelFloat _ (FlatData r))) = View.get view "r"
          Right (Just (ChannelFloat _ (FlatData g))) = View.get view "g"
          Right (Just (ChannelFloat _ (FlatData b))) = View.get view "b"
          Right (Just (ChannelFloat _ (FlatData a))) = View.get view "a"

keyerLuna :: VPS KeyerMode -> VPS Double -> VPS Double -> VPS Double -> VPS Double -> Image RGBA -> Image RGBA
keyerLuna (VPS mode) (VPS (variable -> a)) (VPS (variable -> b)) (VPS (variable -> c)) (VPS (variable -> d)) img =
    keyer' (keyer mode (A.lift $ (a, b, c, d))) img

differenceKeyer' :: (A.Exp (Color.RGB Double) -> A.Exp (Color.RGB Double) -> A.Exp Double) -> Image RGBA -> Image RGBA -> Image RGBA
differenceKeyer' f background foreground = img'
    where backgroundRGB = unsafeGetRGB background
          foregroundRGB = unsafeGetRGB foreground

          alpha = M.map (A.uncurry f) $ M.zip backgroundRGB foregroundRGB

          Just view = lookup "rgba" foreground
          view' = View.append (ChannelFloat "a" (FlatData alpha)) view

          Right img' = Image.update (const $ Just view') "rgba" foreground

differenceKeyerLuna :: VPS Double -> VPS Double -> Image RGBA -> Image RGBA -> Image RGBA
differenceKeyerLuna (VPS (variable -> offset)) (VPS (variable -> gain)) background foreground = img'
    where diff = differenceKeyer offset gain
          img' = differenceKeyer' diff background foreground

cornerPinLuna :: VPS Double -> VPS Double
              -> VPS Double -> VPS Double
              -> VPS Double -> VPS Double
              -> VPS Double -> VPS Double
              -> Image RGBA
              -> Image RGBA
cornerPinLuna (VPS (variable -> p1x)) (VPS (variable -> p1y))
              (VPS (variable -> p2x)) (VPS (variable -> p2y))
              (VPS (variable -> p3x)) (VPS (variable -> p3y))
              (VPS (variable -> p4x)) (VPS (variable -> p4y)) img = img'
    where img' = onEachChannel process img
          process = rasterizer . monosampler . cornerPin (p1, p2, p3, p4) . nearest . fromMatrix (A.Constant 0)
          p1 = Point2 p1x p1y
          p2 = Point2 p2x p2y
          p3 = Point2 p3x p3y
          p4 = Point2 p4x p4y

gaussianLuna :: VPS Int -> Image RGBA -> Image RGBA
gaussianLuna (VPS (variable -> kernelSize)) img = img'
    where img' = onEachChannel process img
          hmat = id M.>-> normalize $ toMatrix (Grid 1 kernelSize) $ gauss 1.0
          vmat = id M.>-> normalize $ toMatrix (Grid kernelSize 1) $ gauss 1.0
          p = pipe A.Clamp
          process x = rasterizer $ id `p` Conv.filter 1 vmat `p` Conv.filter 1 hmat `p` id $ fromMatrix A.Clamp x

gaussianLuna' :: Int -> Image RGBA -> Image RGBA
gaussianLuna' (variable -> kernelSize) img = img'
    where img' = onEachChannel process img
          hmat = id M.>-> normalize $ toMatrix (Grid 1 kernelSize) $ gauss 1.0
          vmat = id M.>-> normalize $ toMatrix (Grid kernelSize 1) $ gauss 1.0
          p = pipe A.Clamp
          process x = rasterizer $ id `p` Conv.filter 1 vmat `p` Conv.filter 1 hmat `p` id $ fromMatrix A.Clamp x

laplacianLuna :: VPS Int -> VPS Double -> VPS Double -> Image RGBA -> Image RGBA
laplacianLuna (VPS (variable -> kernSize)) (VPS (variable -> crossVal)) (VPS (variable -> sideVal)) img = img'
    where img' = onEachChannel process img
          process x = rasterizer $ id `p` Conv.filter 1 flt `p` id $ fromMatrix A.Clamp x
          flt = laplacian crossVal sideVal $ pure kernSize
          p = pipe A.Clamp

circularLuna :: Int -> Int -> Image RGBA
circularLuna = gradientLuna circularShape

conicalLuna :: Int -> Int -> Image RGBA
conicalLuna = gradientLuna conicalShape

squareLuna :: Int -> Image RGBA
squareLuna side = gradientLuna squareShape side side

diamondLuna :: Int -> Int -> Image RGBA
diamondLuna = gradientLuna diamondShape

radialShapeLuna :: (Metric a (Point2 (Exp Double)) (Exp Double), MetricCoord a Cartesian)
                => a -> Int -> Int -> Image RGBA
radialShapeLuna metric w h = gradientLuna (radialShape metric) w h

linearShapeLuna :: Int -> Int -> Image RGBA
linearShapeLuna = gradientLuna linearShape

gradientLuna :: forall e.
                      (A.Lift Exp e,
                       A.Plain e ~ Int) =>
                      Generator (Point2 (Exp Double)) (Exp Double) -> e -> e -> Image RGBA
gradientLuna gradient (variable -> width) (variable -> height) = channelToImageRGBA grad
    where grad = rasterizer $ monosampler $ gradientGenerator

          gradientGenerator = scale (Grid width height) $ translate (V2 0.5 0.5) $ mapper gray gradient
          gray   = [Tick 0.0 0.0 1.0, Tick 1.0 1.0 1.0] :: [Tick Double Double Double]

          weightFun tickPos val1 weight1 val2 weight2 = mix tickPos val1 val2
          mapper = flip colorMapper weightFun

channelToImageRGBA :: Matrix2 Double -> Image RGBA
channelToImageRGBA m = image
    where image = singleton view
          view = View.empty "rgba"
               & View.append (ChannelFloat "r" . FlatData $ m)
               & View.append (ChannelFloat "g" . FlatData $ m)
               & View.append (ChannelFloat "b" . FlatData $ m)
               & View.append (ChannelFloat "a" . FlatData $ alpha)

          alpha :: Matrix2 Double
          alpha = M.generate (M.shape m) (const 1)

perlinLuna :: Double -> Int -> Int -> Image RGBA
perlinLuna (variable -> z) = noiseLuna (perlinNoise z)

billowLuna :: Double -> Int -> Int -> Image RGBA
billowLuna (variable -> z) = noiseLuna (billowNoise z)

noiseLuna :: forall e a.
                   (IsFloating a, Elt a, A.Lift Exp e,
                    A.Plain e ~ Int) =>
                   CartesianGenerator (Exp a) (Exp Double) -> e -> e -> Image RGBA
noiseLuna noise (variable -> width) (variable -> height) = channelToImageRGBA noise'
    where noise' = rasterizer $ monosampler $ noiseGenerator

          noiseGenerator = scale (Grid width height) noise

rotateCenterLuna :: VPS Double -> Matrix2 Double -> Matrix2 Double
rotateCenterLuna (VPS (variable -> angle)) = rasterizer . monosampler . rotateCenter angle . nearest . fromMatrix (A.Constant 0)

translateLuna :: A.Boundary (A.Exp Double) -> Double -> Double -> Image RGBA -> Image RGBA
translateLuna boundary (variable -> x) (variable -> y) = onEachChannel $ rasterizer . monosampler . translate (V2 x y) . nearest . fromMatrix boundary

hsvToolLuna :: VPS Double -> VPS Double -> VPS Double -> VPS Double
            -> VPS Double -> VPS Double -> VPS Double -> VPS Double
            -> VPS Double -> VPS Double -> VPS Double -> VPS Double
            -> A.Exp (Color.RGB Double)
            -> A.Exp (Color.RGB Double)
hsvToolLuna (VPS (variable -> hueRangeStart)) (VPS (variable -> hueRangeEnd))
            (VPS (variable -> hueRotation)) (VPS (variable -> hueRolloff))
            (VPS (variable -> saturationRangeStart)) (VPS (variable -> saturationRangeEnd))
            (VPS (variable -> saturationAdjustment)) (VPS (variable -> saturationRolloff))
            (VPS (variable -> brightnessRangeStart)) (VPS (variable -> brightnessRangeEnd))
            (VPS (variable -> brightnessAdjustment)) (VPS (variable -> brightnessRolloff)) =
    A.lift1 (hsvTool (A.lift $ Range hueRangeStart hueRangeEnd) hueRotation hueRolloff
                     (A.lift $ Range saturationRangeStart saturationRangeEnd) saturationAdjustment saturationRolloff
                     (A.lift $ Range brightnessRangeStart brightnessRangeEnd) brightnessAdjustment brightnessRolloff :: Color.RGB (A.Exp Double) -> Color.RGB (A.Exp Double))

hsvToolLuna' :: Double -> Double -> Double -> Double
             -> Double -> Double -> Double -> Double
             -> Double -> Double -> Double -> Double
             -> Image RGBA
             -> Image RGBA
hsvToolLuna' (variable -> hueRangeStart) (variable -> hueRangeEnd)
             (variable -> hueRotation) (variable -> hueRolloff)
             (variable -> saturationRangeStart) (variable -> saturationRangeEnd)
             (variable -> saturationAdjustment) (variable -> saturationRolloff)
             (variable -> brightnessRangeStart) (variable -> brightnessRangeEnd)
             (variable -> brightnessAdjustment) (variable -> brightnessRolloff) =
    onEachRGB $ A.lift1 (hsvTool (A.lift $ Range hueRangeStart hueRangeEnd) hueRotation hueRolloff
                     (A.lift $ Range saturationRangeStart saturationRangeEnd) saturationAdjustment saturationRolloff
                     (A.lift $ Range brightnessRangeStart brightnessRangeEnd) brightnessAdjustment brightnessRolloff :: Color.RGB (A.Exp Double) -> Color.RGB (A.Exp Double))

-- test :: VPS Double -> VPS Double -> VPS Double -> VPS Double
--      -> VPS Double -> VPS Double -> VPS Double -> VPS Double
--      -> VPS Double -> VPS Double -> VPS Double -> VPS Double
--      -> VPS (Image RGBA) -> VPS (Image RGBA)
test = liftF13 hsvToolLuna'

liftF13 fun a b c d e f g h i j k l m = do
    a' <- a
    b' <- b
    c' <- c
    d' <- d
    e' <- e
    f' <- f
    g' <- g
    h' <- h
    i' <- i
    j' <- j
    k' <- k
    l' <- l
    m' <- m
    val fun <<*>> a' <<*>> b' <<*>> c' <<*>> d' <<*>> e' <<*>> f'
            <<*>> g' <<*>> h' <<*>> i' <<*>> j' <<*>> k' <<*>> l' <<*>> m'

liftF12 fun a b c d e f g h i j k l = do
    a' <- a
    b' <- b
    c' <- c
    d' <- d
    e' <- e
    f' <- f
    g' <- g
    h' <- h
    i' <- i
    j' <- j
    k' <- k
    l' <- l
    val fun <<*>> a' <<*>> b' <<*>> c' <<*>> d' <<*>> e' <<*>> f'
            <<*>> g' <<*>> h' <<*>> i' <<*>> j' <<*>> k' <<*>> l'

data MergeMode = Atop
           | Average
           | ColorBurn
           | ColorDodge
           | ConjointOver
           | Copy
           | Difference
           | DisjointOver
           | DivideBySource
           | DivideByDestination
           | Exclusion
           | From
           | Geometric
           | HardLight
           | Hypot
           | In
           | Mask
           | Matte
           -- | Max
           -- | Min
           | Minus
           | Multiply
           | Out
           | Over
           | Overlay
           | Plus
           | Screen
           | SoftLight
           | SoftLightPegtop
           | SoftLightIllusions
           | SoftLightPhotoshop
           | Stencil
           | Under
           | XOR
           deriving (Show)

mergeLuna :: MergeMode -> Merge.AlphaBlend -> Image RGBA -> Image RGBA -> Image RGBA
mergeLuna mode alphaBlend img1 img2 = case mode of
    Atop                -> processMerge $ Merge.threeWayMerge             Merge.atop
    Average             -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.average
    ColorBurn           -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.colorBurn
    ColorDodge          -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.colorDodge
    ConjointOver        -> processMerge $ Merge.threeWayMerge             Merge.conjointOver
    Copy                -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.copy
    Difference          -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.difference
    DisjointOver        -> processMerge $ Merge.threeWayMerge             Merge.disjointOver
    DivideBySource      -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.divideBySrc
    DivideByDestination -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.divideByDst
    Exclusion           -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.exclusion
    From                -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.from
    Geometric           -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.geometric
    HardLight           -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.hardLight
    Hypot               -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.hypot
    In                  -> processMerge $ Merge.threeWayMerge             Merge.inBlend
    Mask                -> processMerge $ Merge.threeWayMerge             Merge.withMask
    Matte               -> processMerge $ Merge.threeWayMerge             Merge.matte
    -- Max                 -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.max
    -- Min                 -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.min
    Minus               -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.minus
    Multiply            -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.multiply
    Out                 -> processMerge $ Merge.threeWayMerge             Merge.out
    Over                -> processMerge $ Merge.threeWayMerge             Merge.over
    Overlay             -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.overlayFun
    Plus                -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.plus
    Screen              -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.screen
    SoftLight           -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.softLight
    SoftLightPegtop     -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.softLightPegtop
    SoftLightIllusions  -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.softLightIllusions
    SoftLightPhotoshop  -> processMerge $ Merge.threeWayMerge' alphaBlend Merge.softLightPhotoshop
    Stencil             -> processMerge $ Merge.threeWayMerge             Merge.stencil
    Under               -> processMerge $ Merge.threeWayMerge             Merge.under
    XOR                 -> processMerge $ Merge.threeWayMerge             Merge.xor
    where processMerge f = img'
              where (r, g, b, a) = f r1 g1 b1 r2 g2 b2 a1 a2
                    view' = view
                          & View.append (ChannelFloat "r" (FlatData $ rasterizer $ r))
                          & View.append (ChannelFloat "g" (FlatData $ rasterizer $ g))
                          & View.append (ChannelFloat "b" (FlatData $ rasterizer $ b))
                          & View.append (ChannelFloat "a" (FlatData $ rasterizer $ a))
                    Right img' = Image.update (const $ Just view') "rgba" img1
          Just view = lookup "rgba" img1
          (r1, g1, b1, a1) = unsafeGetChannels img1 & over each (fromMatrix (A.Constant 0))
          (r2, g2, b2, a2) = unsafeGetChannels img2 & over each (fromMatrix (A.Constant 0))

onGenerator f img = img'
    where (r, g, b, a) = unsafeGetChannels img & over each (rasterizer . f . fromMatrix (A.Constant 0))
          Just view = lookup "rgba" img
          view' = view
                & View.append (ChannelFloat "r" (FlatData r))
                & View.append (ChannelFloat "g" (FlatData g))
                & View.append (ChannelFloat "b" (FlatData b))
                & View.append (ChannelFloat "a" (FlatData a))
          Right img' = Image.update (const $ Just view') "rgba" img

erodeLuna :: Int -> Image RGBA -> Image RGBA
erodeLuna (variable -> size) = onGenerator $ erode $ pure size

dilateLuna :: Int -> Image RGBA -> Image RGBA
dilateLuna (variable -> size) = onGenerator $ dilate $ pure size

closeLuna :: Int -> Image RGBA -> Image RGBA
closeLuna (variable -> size) = onGenerator $ closing $ pure size

openLuna :: Int -> Image RGBA -> Image RGBA
openLuna (variable -> size) = onGenerator $ opening $ pure size

premultiplyLuna :: Image RGBA -> Image RGBA
premultiplyLuna img = (*) `withAlpha` img

unpremultiplyLuna :: Image RGBA -> Image RGBA
unpremultiplyLuna img = (/) `withAlpha` img

withAlpha :: (A.Exp Double -> A.Exp Double -> A.Exp Double) -> Image RGBA -> Image RGBA
withAlpha f img = img'
    where (r, g, b, a) = unsafeGetChannels img
          r' = M.zipWith f r a
          g' = M.zipWith f g a
          b' = M.zipWith f b a

          Just view = lookup "rgba" img
          view' = view
                & View.append (ChannelFloat "r" (FlatData r'))
                & View.append (ChannelFloat "g" (FlatData g'))
                & View.append (ChannelFloat "b" (FlatData b'))
                & View.append (ChannelFloat "a" (FlatData a))
          Right img' = Image.update (const $ Just view') "rgba" img

invertLuna :: Image RGBA -> Image RGBA
invertLuna = onEachValue invert

colorMatrixLuna :: ColorMatrix Color.RGB Double -> Image RGBA -> Image RGBA
colorMatrixLuna matrix = onEachRGB (A.lift1 $ (colorMatrix :: ColorMatrix Color.RGB Double -> Color.RGB (A.Exp Double) -> Color.RGB (A.Exp Double)) matrix)

clampLuna :: Double -> Double -> Double -> Double -> Image RGBA -> Image RGBA
clampLuna (variable -> thLo) (variable -> thHi) (variable -> clampLo) (variable -> clampHi) =
    onEachValue (clamp (Range thLo thHi) (Just $ Range clampLo clampHi))

multiplyLuna :: Double -> Image RGBA -> Image RGBA
multiplyLuna (variable -> v) = onEachValue (*v)

gammaLuna :: Double -> Image RGBA -> Image RGBA
gammaLuna (variable -> v) = onEachValue (gamma v)

fromPolarMapping :: (Elt a, IsFloating a, Elt e) => CartesianGenerator (Exp a) (Exp e) -> CartesianGenerator (Exp a) (Exp e)
fromPolarMapping (Generator cnv gen) = Generator cnv $ \(Point2 x y) ->
    let Grid cw ch = fmap A.fromIntegral cnv
        radius = (sqrt $ x * x + y * y) / (sqrt $ cw * cw + ch * ch)
        angle  = atan2 y x / (2 * pi)
    in gen (Point2 (angle * cw) (radius * ch))

toPolarMapping :: (Elt a, IsFloating a, Elt e) => CartesianGenerator (Exp a) (Exp e) -> CartesianGenerator (Exp a) (Exp e)
toPolarMapping (Generator cnv gen) = Generator cnv $ \(Point2 angle' radius') ->
    let Grid cw ch = fmap A.fromIntegral cnv
        angle = (angle' / cw) * 2 * pi
        radius = (radius' / ch) * (sqrt $ cw * cw + ch * ch)
    in gen (Point2 (radius * cos angle) (radius * sin angle))

radialBlurLuna :: Int -> Double -> Image RGBA -> Image RGBA
radialBlurLuna (variable -> size) (variable -> angle) = onEachChannel process
    where kern = monosampler
               $ rotateCenter angle
               $ nearest
               $ rectangle (Grid size 1) 1 0
          process = rasterizer
                  . monosampler
                  . translate (V2 (256) (256))
                  . fromPolarMapping
                  . nearest
                  . normStencil (+) kern (+) 0
                  . monosampler
                  . toPolarMapping
                  . translate (V2 (-256) (-256))
                  . nearest
                  . fromMatrix A.Clamp

histEqLuna :: Int -> Image RGBA -> Image RGBA
histEqLuna (variable -> bins) img = img'
    where rgb = unsafeGetRGB img
          hsv = M.map Color.liftedConvertColor rgb
          v   = M.map (\(A.unlift -> Color.HSV _ _ v) -> v) hsv
          v'  = M.Delayed $ histeq bins (M.accMatrix v)
          hsv' = M.zipWith (\(A.unlift -> Color.HSV h s _) v -> A.lift $ Color.HSV h s v) hsv v'
          rgb' = M.map Color.liftedConvertColor hsv'
          (r, g, b) = M.unzip3 $ M.map (\(A.unlift -> Color.RGB r g b) -> A.lift (r, g, b)) rgb'

          Just view = lookup "rgba" img

          view' = view
                & View.append (ChannelFloat "r" (FlatData r))
                & View.append (ChannelFloat "g" (FlatData g))
                & View.append (ChannelFloat "b" (FlatData b))

          Right img' = Image.update (const $ Just view') "rgba" img

ditherLuna :: A.Boundary (MValue Double) -> Int -> DiffusionTable Double -> Image RGBA -> IO (Image RGBA)
ditherLuna boundary bits table img = do
    let (r, g, b, a) = unsafeGetChannels img
        ditherMethod = dither boundary table bits
    r' <- mutableProcess run ditherMethod r
    g' <- mutableProcess run ditherMethod g
    b' <- mutableProcess run ditherMethod b

    let Just view = lookup "rgba" img
        view' = view
              & View.append (ChannelFloat "r" (FlatData r'))
              & View.append (ChannelFloat "g" (FlatData g'))
              & View.append (ChannelFloat "b" (FlatData b'))
        Right img' = Image.update (const $ Just view') "rgba" img

    return img'

orderedDitherLuna :: Int -> Image RGBA -> Image RGBA
orderedDitherLuna bits = onEachChannel $ bayer bits

constantBoundaryWrapper :: a -> A.Boundary (MValue a)
constantBoundaryWrapper v = A.Constant $ MValue (return v) (const $ return ())
