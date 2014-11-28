---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns        #-}

module Flowbox.Graphics.Image.Color (
    module Flowbox.Graphics.Image.Color,
    U.Range(..),
    U.bias,
    U.clamp',
    U.clamp,
    U.gain,
    U.gamma,
    U.invert,
    U.mix
) where

import qualified Data.Array.Accelerate       as A
import           Data.Array.Accelerate.Tuple (IsTuple, TupleRepr, fromTuple, toTuple)
import           Data.Array.Accelerate.Type  (IsScalar)

import           Flowbox.Graphics.Composition.Generators.Structures
import           Flowbox.Graphics.Color
import qualified Flowbox.Graphics.Utils                             as U
import           Flowbox.Math.Matrix                                as M
import           Flowbox.Prelude                                    as P hiding (lift)



offset :: (Num a) => a -> a -> a
offset v = (+v)

multiply :: (Num a) => a -> a -> a
multiply v = (*v)

contrast :: (Num a, Fractional a) => a -> a -> a
contrast v x = (x - 0.5) * v + 0.5

data Colorspace = Linear | Cineon

exposure :: (Num a, Floating a) => a -> a -> a -> a
exposure blackpoint ex pix = blackpointConvert blackpoint (2 ** ex * inverseBlackpointConvert blackpoint pix)

blackpointConvert :: (Num a, Floating a) => a -> a -> a
blackpointConvert blackpoint = pointsConvert blackpoint 1.0

inverseBlackpointConvert :: (Num a, Floating a) => a -> a -> a
inverseBlackpointConvert lift = inversePointsConvert lift 1.0

whitepointConvert :: (Num a, Floating a) => a -> a -> a
whitepointConvert = pointsConvert 0.0

inverseWhitepointConvert :: (Num a, Floating a) => a -> a -> a
inverseWhitepointConvert = inversePointsConvert 0.0

pointsConvert :: (Num a, Floating a) => a -> a -> a -> a
pointsConvert blackpoint whitepoint pix = (pix - blackpoint) / (whitepoint - blackpoint)

inversePointsConvert :: (Num a, Floating a) => a -> a -> a -> a
inversePointsConvert lift gain pix = (gain - lift) * pix + lift

grade :: (Num a, Floating a) => a -> a -> a -> a -> a -> a -> a -> a -> a
grade blackpoint whitepoint lift gain multiply' offset' gamma =
	U.gamma gamma . offset offset' . multiply multiply' . inversePointsConvert lift gain . pointsConvert blackpoint whitepoint

colorCorrect :: forall a. (Elt a, IsFloating a)
             => Exp a       -- ^ saturation
             -> Exp a       -- ^ contrast
             -> Exp a       -- ^ gamma
             -> Exp a       -- ^ gain
             -> Exp a       -- ^ offset
             -> Exp (RGB a) -- ^ input pixel
             -> Exp (RGB a)
colorCorrect = ((((A.lift1 .) .) .) .) . colorCorrect'
    where colorCorrect' :: Exp a -> Exp a -> Exp a -> Exp a -> Exp a -> RGB (Exp a) -> RGB (Exp a)
          colorCorrect' saturation' contrast' gamma' gain' offset' pix' = saturated & each %~ (offset offset' . gain'' gain' . U.gamma gamma' . contrast contrast')
              where saturated  = toHSV pix' & (\(HSV h s v) -> HSV h (s * saturation') v) & toRGB
                    gain'' b x = b * x -- U.gain is broken, tested with Nuke that it's simply multiplication

-- NOTE[mm]: pretty sure Nuke uses HSL colorspace for saturation manipulation. There are slight differences still,
--           but operating on HSV looks unalike to Nuke.
saturate :: (Elt t, IsFloating t, ColorConvert a HSL, ColorConvert HSL a) => Exp t -> a (Exp t) -> a (Exp t)
saturate saturation pix = toHSL pix & (\(HSL h s l) -> HSL h (s * saturation) l) & convertColor

hsvTool :: forall a t. (Elt t, IsFloating t, ColorConvert a HSV, ColorConvert HSV a,
                        A.Lift Exp (a (Exp t)), A.Unlift Exp (a (Exp t)), Elt (A.Plain (a (Exp t))))
        => Exp (U.Range t) -> Exp t -> Exp t
        -> Exp (U.Range t) -> Exp t -> Exp t
        -> Exp (U.Range t) -> Exp t -> Exp t
        -> a (Exp t)
        -> a (Exp t)
hsvTool (A.unlift . U.variable -> hueRange) (U.variable -> hueRotation) (U.variable -> hueRolloff)
        (A.unlift . U.variable -> saturationRange) (U.variable -> saturationAdjustment) (U.variable -> saturationRolloff)
        (A.unlift . U.variable -> brightnessRange) (U.variable -> brightnessAdjustment) (U.variable -> brightnessRolloff) pix =
    A.unlift (conditionsFulfilled A.? (
        A.lift (HSV (rotation (hueRotation * cyclicPower hueRange hueRolloff h) h)
                    (s + saturationAdjustment * power saturationRange saturationRolloff s)
                    (v + brightnessAdjustment * power brightnessRange brightnessRolloff v)
                & convertColor :: a (Exp t))
        ,
        A.lift pix))
    where HSV h s v = toHSV pix
          rotation r hue = U.frac $ hue + r

          conditionsFulfilled = cyclicPower hueRange        hueRolloff        h A.>* 0
                                A.&&*
                                power       saturationRange saturationRolloff s A.>* 0
                                A.&&*
                                power       brightnessRange brightnessRolloff v A.>* 0

power :: forall a. (Elt a, IsFloating a) => U.Range (Exp a) -> Exp a -> Exp a -> Exp a
power range@(U.Range a' b') rolloff x =
    let a = U.variable a'
        b = U.variable b'

        rLeft  = U.Range (a - rolloff) a
        rRight = U.Range b (b + rolloff)

        rLeftEquation val = aLinear * val + bLinear
            where (aLinear, bLinear) = rise a rolloff

        rRightEquation val = aLinear * val + bLinear
            where (aLinear, bLinear) = fall b rolloff
    in A.cond (x `inRange` range) 1
       $ A.cond (x `inRange` rLeft) (rLeftEquation x)
       $ A.cond (x `inRange` rRight) (rRightEquation x)
       0

inRange :: (Elt a, IsScalar a) => Exp a -> U.Range (Exp a) -> Exp Bool
inRange val (U.Range a b) = val A.>=* a A.&&* val A.<=* b


-- | Used to compute power of hue rotation effect. It properly cycles on multiplies
--   of 360 degrees in both directions.
cyclicPower :: forall a. (Elt a, IsFloating a) => U.Range (Exp a) -> Exp a -> Exp a -> Exp a
cyclicPower (U.Range a' b') rolloff x =
    let a = U.variable a'
        b = U.variable b'
        (correct, pp') = intersection a b rolloff :: (Exp Bool, Exp a)
        pp = U.variable pp'
        (rLeft, rRight) = A.unlift (correct A.? (A.lift ((pp-1,a), (b,pp))
                                     , A.lift ((a-rolloff, a), (b, b+rolloff)))) :: (A.Exp (a, a), A.Exp (a, a))
        rLeftEquation val = A.cond (frL A./=* 0) (fxL val / frL) 1
        rRightEquation val = A.cond (frR A./=* 0) (1 - fxR val / frR) 1

        fxL val = U.frac $ val - tL
        frL     = U.frac $ a - tL

        fxR val = U.frac $ val - tR
        frR     = U.frac rolloff -- == b+r - tR == b+r - b == r

        tL      = U.frac $ a - rolloff
        tR      = U.frac b
    in check x (a,b) A.? (1,
       check x (A.unlift rLeft) A.? (rLeftEquation x,
       check x (A.unlift rRight) A.? (rRightEquation x, 0)))

intersection :: (A.Elt a, A.IsFloating a) => Exp a -> Exp a -> Exp a -> (Exp Bool, Exp a)
intersection a b r = (y A.>* 0 A.&&* y A.<* 1, x)
    where x = (b2 - b1) / (a1 - a2)
          y = a1*((b2-b1)/(a1-a2))+b1
          (a1, b1) = rise a r
          (a2, b2) = fall b r

rise :: Fractional t => t -> t -> (t, t)
rise a r = (1/r, 1-(a+1)/r)

fall :: Fractional t => t -> t -> (t, t)
fall b r = ((-1)/r, 1+(b/r))

check :: (A.Elt a, A.IsFloating a) => Exp a -> (Exp a, Exp a) -> Exp Bool
check (U.frac -> x) (a,b) =
    let a' = U.frac a
        b' = U.frac b
    in (b-a A.>=* 1)
       A.||*
       (x A.>=* a' A.&&* x A.<=* b')
       A.||*
       (b' A.<* a' A.&&* ((x A.>=* a' A.&&* x A.>=* b')
           A.||*
           (x A.<=* a' A.&&* x A.<=* b')))



conditionally :: (Elt a, IsScalar a) => U.Range (Exp a) -> (Exp a -> Exp a) -> Exp a -> Exp a
conditionally (U.Range low high) f val = val A.>=* low A.&&* val A.<=* high A.? (f val, val)

-- | Lowers number of colors in a picture to 2^colors
posterize :: (Elt a, IsFloating a) => Exp a -> Exp a -> Exp a
posterize colors val = A.cond (colors A.==* 0) 0
                     $ A.cond (colors A.==* 1) 1
                     $ s * A.fromIntegral (A.floor $ val / t :: Exp Int)
    where s = 1 / (colors - 1)
          t = 1 / colors


type Vec3 a   = (Exp  a, Exp  a, Exp  a)
type Mat3x3 a = (Vec3 a, Vec3 a, Vec3 a)

type Vec4 a   = (Exp  a, Exp  a, Exp  a, Exp  a)
type Mat4x4 a = (Vec4 a, Vec4 a, Vec4 a, Vec4 a)

-- | Dispatches colorspace to required color matrix

type family ColorMatrix (colorspace :: * -> *) t :: *

type instance ColorMatrix CMY      t = Mat3x3 t
type instance ColorMatrix CMYK     t = Mat4x4 t
type instance ColorMatrix HSL      t = Mat3x3 t
type instance ColorMatrix HSV      t = Mat3x3 t
type instance ColorMatrix RGB      t = Mat3x3 t
type instance ColorMatrix RGBA     t = Mat4x4 t
type instance ColorMatrix YCbCr    t = Mat3x3 t
type instance ColorMatrix YCbCr_HD t = Mat3x3 t

-- | Multiplies given matrix by colour.
--   Matrix needs to be in a row major order and n x n size, where n is a number
--   of components in a colour.
--
--   Example:
--   ((1, 0, 0),     (0.5,     (0.5,
--    (0, 1, 1),  *   0.6,  =   1.6,
--    (0, 0, 1))      1.0)      1.0)

colorMatrix :: (Elt t, IsFloating t, MatrixMultiplication a) => ColorMatrix a t -> a (Exp t) -> a (Exp t)
colorMatrix = mmult

class MatrixMultiplication colorspace where
    mmult :: (Elt t, IsNum t) => ColorMatrix colorspace t -> colorspace (Exp t) -> colorspace (Exp t)

instance MatrixMultiplication CMY where
    mmult = mul3x3

instance MatrixMultiplication CMYK where
    mmult = mul4x4

instance MatrixMultiplication HSL where
    mmult = mul3x3

instance MatrixMultiplication HSV where
    mmult = mul3x3

instance MatrixMultiplication RGB where
    mmult = mul3x3

instance MatrixMultiplication RGBA where
    mmult = mul4x4

instance MatrixMultiplication YCbCr where
    mmult = mul3x3

instance MatrixMultiplication YCbCr_HD where
    mmult = mul3x3

mul3x3 :: (IsTuple (a (Exp t)), Elt t, IsNum t, TupleRepr (a (Exp t)) ~ TupleRepr (Vec3 t)) => Mat3x3 t -> a (Exp t) -> a (Exp t)
mul3x3 ((a, b, c), (d, e, f), (g, h, i)) pix = toTuple ((((), x'), y'), z')
    where ((((), x), y), z) = fromTuple pix
          x' = a * x + b * y + c * z
          y' = d * x + e * y + f * z
          z' = g * x + h * y + i * z

mul4x4 :: (IsTuple (a (Exp t)), Elt t, IsNum t, TupleRepr (a (Exp t)) ~ TupleRepr (Vec4 t))
       => Mat4x4 t -> a (Exp t) -> a (Exp t)
mul4x4 ((a, b, c, d), (e, f, g, h), (i, j, k, l), (m, n, o, p)) pix = toTuple (((((), x'), y'), z'), w')
    where (((((), x), y), z), w) = fromTuple pix
          x' = a * x + b * y + c * z + d * w
          y' = e * x + f * y + g * z + h * w
          z' = i * x + j * y + k * z + l * w
          w' = m * x + n * y + o * z + p * w


data LinearGenerator a = LinearGenerator { runBezier :: a -> a }

crosstalk :: (A.Elt a, A.IsFloating a)
          => LinearGenerator (A.Exp a) -- ^ red channel curve
          -> LinearGenerator (A.Exp a) -- ^ green channel curve
          -> LinearGenerator (A.Exp a) -- ^ blue channel curve
          -> LinearGenerator (A.Exp a) -- ^ r->g curve
          -> LinearGenerator (A.Exp a) -- ^ r->b curve
          -> LinearGenerator (A.Exp a) -- ^ g->r curve
          -> LinearGenerator (A.Exp a) -- ^ g->b curve
          -> LinearGenerator (A.Exp a) -- ^ b->r curve
          -> LinearGenerator (A.Exp a) -- ^ b->g curve
          -> Generator x (A.Exp a)         -- ^ r channel
          -> Generator x (A.Exp a)         -- ^ g channel
          -> Generator x (A.Exp a)         -- ^ b channel
          -> (Generator x (A.Exp a), Generator x (A.Exp a), Generator x (A.Exp a))
crosstalk redBezier greenBezier blueBezier
          redGreenBezier redBlueBezier
          greenRedBezier greenBlueBezier
          blueRedBezier blueGreenBezier
          red green blue = (newRed, newGreen, newBlue)
    where newRed   = Generator (canvas red)   $ \x ->
              runGenerator redBeziered x + runGenerator greenToRed x + runGenerator blueToRed x

          newGreen = Generator (canvas green) $ \x ->
              runGenerator greenBeziered x + runGenerator redToGreen x + runGenerator blueToGreen x

          newBlue  = Generator (canvas blue)  $ \x ->
              runGenerator blueBeziered x + runGenerator redToBlue x + runGenerator greenToBlue x

          redBeziered = Generator (canvas red) $ \x -> let redColor = runGenerator red x
                                                       in  runBezier redBezier redColor

          redToGreen = Generator (canvas red) $ \x -> let redColor = runGenerator red x
                                                      in  runBezier redGreenBezier redColor

          redToBlue = Generator (canvas red) $ \x -> let redColor = runGenerator red x
                                                     in  runBezier redBlueBezier redColor

          greenBeziered = Generator (canvas green) $ \x -> let greenColor = runGenerator green x
                                                           in  runBezier greenBezier greenColor

          greenToRed = Generator (canvas green) $ \x -> let greenColor = runGenerator green x
                                                        in  runBezier greenRedBezier greenColor

          greenToBlue = Generator (canvas green) $ \x -> let greenColor = runGenerator green x
                                                         in  runBezier greenBlueBezier greenColor

          blueBeziered = Generator (canvas blue) $ \x -> let blueColor = runGenerator blue x
                                                         in  runBezier blueBezier blueColor

          blueToRed = Generator (canvas blue) $ \x -> let blueColor = runGenerator blue x
                                                      in  runBezier blueRedBezier blueColor

          blueToGreen = Generator (canvas blue) $ \x -> let blueColor = runGenerator blue x
                                                        in  runBezier blueGreenBezier blueColor 

