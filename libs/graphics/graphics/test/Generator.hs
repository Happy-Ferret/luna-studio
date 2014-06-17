---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Main where

import Flowbox.Prelude
import Flowbox.Graphics.Composition.Generators.Gradient
import Flowbox.Graphics.Composition.Generators.Lambda
import Flowbox.Graphics.Composition.Generators.Multisampler
import Flowbox.Graphics.Composition.Generators.Structures

import Linear.V2
import Math.Space.Space
import Math.Metric
import Math.Coordinate.Cartesian
import Data.Array.Accelerate (index2)

import Utils

mytest (w, h) (x1, y1, x2, y2) shape = do
    let reds   = [Tick 0.0 1.0 1.0, Tick 0.25 0.0 1.0, Tick 1.0 1.0 1.0]
    let greens = [Tick 0.0 1.0 1.0, Tick 0.50 0.0 1.0, Tick 1.0 1.0 1.0]
    let blues  = [Tick 0.0 1.0 1.0, Tick 0.75 0.0 1.0, Tick 1.0 1.0 1.0]
    let alphas = [Tick 0.0 0.0 1.0, Tick 1.0 1.0 1.0]
    let myftrans pw nw prop = prop ** (pw / nw)
    
    let vec = V2 (Point2 x1 y1) (Point2 x2 y2)
    let mykernel = gaussianKernel (index2 5 5) 1.0
    let gradient ticks = lambdaGenerator (Grid w h) $ colorMapper vec ticks myftrans shape

    testSaveRGBA "out.bmp" (gradient reds) (gradient greens) (gradient blues) (gradient alphas)
    --testSaveChan "out.bmp" (gradient alphas)

    --let gauss = gaussianKernel (index2 512 512) (1.0)
    --testSaveChan "out.bmp" gauss

main :: IO ()
main = do
    putStrLn "Testuję gradient"
