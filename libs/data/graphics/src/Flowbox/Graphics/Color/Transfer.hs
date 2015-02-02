---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE CPP                 #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE KindSignatures      #-}
{-# LANGUAGE OverloadedLists     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE ViewPatterns        #-}

module Flowbox.Graphics.Color.Transfer where

import qualified Data.Array.Accelerate    as A
import qualified Data.Array.Accelerate.IO as AIO

#ifdef ACCELERATE_CUDA_BACKEND
import Data.Array.Accelerate.CUDA (run)
#else
import Data.Array.Accelerate.Interpreter (run)
#endif

import           Flowbox.Graphics.Composition.Histogram
import           Flowbox.Graphics.Utils.Accelerate
import qualified Flowbox.Graphics.Utils.Utils           as U
import qualified Flowbox.Math.Numeric                   as Num
import           Flowbox.Prelude




rotation :: A.Acc (A.Array A.DIM2 Float)
rotation = A.map (/ sqrt 2) $ A.use $ A.fromList (A.Z A.:. 6 A.:. 3)
         [  0.427019, -0.112186,  0.897256
         ,  0.886757, -0.142236, -0.439807
         , -0.176963, -0.983455, -0.038744
         ,  0.934839,  0.158203,  0.317881
         , -0.128881, -0.683015,  0.718944
         ,  0.330857, -0.713065, -0.618119
         ]

bigG :: A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float)
bigG = Num.matMul rotation

bigR :: A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float)
bigR = Num.matMul rotation

smin :: A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM1 Float)
smin h p = A.fold1 min $ bigG h A.++ bigR p

smax :: A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM1 Float)
smax h p = A.fold1 max $ bigG h A.++ bigR p


rhoGi :: A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array ((A.Z A.:. Int) A.:. Int) Int)
rhoGi h p = A.reshape (A.index2 6 (256 :: A.Exp Int))
     $ A.asnd
     $ A.awhile
         (\v -> A.unit $ A.the (A.afst v) A.<* 6)
         rhoGiStep
         (A.lift (A.unit $ A.constant 0, emptyVector))
 where
   rhoGiStep :: A.Acc (A.Scalar Int, A.Vector Int) -> A.Acc (A.Scalar Int, A.Vector Int)
   rhoGiStep (A.unlift -> (it', vec) :: (A.Acc (A.Scalar Int), A.Acc (A.Vector Int))) =
     let currentIteration = A.the it'

         currentMin = smin h p A.!! currentIteration
         currentMax = smax h p A.!! currentIteration

         sliceG = A.slice (bigG h) (A.lift $ A.Z A.:. currentIteration A.:. A.All)

     in  A.lift ( A.unit (currentIteration + 1)
                , vec A.++ histogram' (histogram currentMin currentMax 256 sliceG)
                )

--histogram' :: forall a. (A.Elt a, A.IsFloating a) => Histogram a -> A.Acc (A.Vector a)
--histogram' (A.unlift -> (hist, _, _) :: Histogram' a) = normalizeHistogram hist
histogram' :: forall (c :: * -> *) a. A.Unlift c (Histogram' a) => c (A.Array A.DIM1 Int, A.Array A.DIM0 a, A.Array A.DIM0 a) -> A.Acc (A.Vector Int)
histogram' (A.unlift -> (hist, _, _) :: Histogram' a) = hist

normalizeHistogram :: (A.Elt e, A.IsFloating e) => A.Acc (A.Vector Int) -> A.Acc (A.Vector e)
normalizeHistogram hist = A.map (\x -> A.fromIntegral x / sum') hist
  where
    sum' = A.fromIntegral $ A.the $ A.sum hist


histogramWithBins' :: (A.Elt e, A.IsFloating e) => A.Exp e -> A.Exp e -> A.Exp Int -> A.Acc (A.Vector e) -> A.Acc (A.Vector Int)
histogramWithBins' mini maxi bins vec = A.permute (+) zeros hist ones
  where
    bins' = U.variable bins
    step  = (maxi - mini) / (A.fromIntegral bins' - 1)

    zeros = A.fill (A.index1 bins') (A.constant 0 :: A.Exp Int)
    ones  = A.fill (A.shape vec)    (A.constant 1 :: A.Exp Int)

    hist idx = A.index1 (A.ceiling $ ((vec A.! idx) - mini) / step :: A.Exp Int)

-- szatan = do
--   (plainR, plainG, plainB) <- loadRGBA "samples/transfer/scotland_plain.bmp"
--   (houseR, houseG, houseB) <- loadRGBA "samples/transfer/scotland_house.bmp"
--   putStrLn "loaded"

--   let vectoredPlain = customReshape $ A.lift (A.use plainR, A.use plainG, A.use plainB)
--       vectoredHouse = customReshape $ A.lift (A.use houseR, A.use houseG, A.use houseB)

--   let (r, g, b) = A.unlift $ reshapeBack (A.shape $ A.use plainR) $ rhoGi vectoredHouse vectoredPlain

--   return foo

customReshape :: A.Acc (A.Array A.DIM2 Float, A.Array A.DIM2 Float, A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float)
customReshape (A.unlift -> (r, g, b) :: Vectors) = A.reshape newShape (A.flatten r A.++ A.flatten g A.++ A.flatten b)
  where
    newShape = A.index2 3 $ A.size r

reshapeBack :: A.Exp A.DIM2 -> A.Acc (A.Array A.DIM2 Float) -> A.Acc (A.Array A.DIM2 Float, A.Array A.DIM2 Float, A.Array A.DIM2 Float)
reshapeBack sh input = A.lift (A.reshape sh r, A.reshape sh g, A.reshape sh b)
  where r = A.slice input (A.lift $ A.Z A.:. (0 :: A.Exp Int) A.:. A.All)
        g = A.slice input (A.lift $ A.Z A.:. (1 :: A.Exp Int) A.:. A.All)
        b = A.slice input (A.lift $ A.Z A.:. (2 :: A.Exp Int) A.:. A.All)

type Vectors = (A.Acc (A.Array A.DIM2 Float), A.Acc (A.Array A.DIM2 Float), A.Acc (A.Array A.DIM2 Float))

convert :: forall (c :: * -> *) (c1 :: * -> *) b b1 b2.
           (A.Lift c1 (A.Exp b, A.Exp b1, A.Exp b2), A.Unlift c (A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8), A.IsFloating b2, A.IsFloating b1, A.IsFloating b, A.Elt b2, A.Elt b1, A.Elt b)
        => c (A.Word8, A.Word8, A.Word8, A.Word8) -> c1 (b, b1, b2)
convert t = let (r, g, b, _) = A.unlift t :: (A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8, A.Exp A.Word8)
            in  A.lift (A.fromIntegral r / 255, A.fromIntegral g / 255, A.fromIntegral b / 255)

loadRGBA :: FilePath -> IO (A.Array A.DIM2 Float, A.Array A.DIM2 Float, A.Array A.DIM2 Float)
loadRGBA file = do
  Right file' <- AIO.readImageFromBMP file
  return $ run $ A.lift $ A.unzip3 $ A.map (convert . AIO.unpackRGBA32) $ A.use file'
