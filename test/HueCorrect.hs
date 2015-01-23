---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ViewPatterns              #-}

module Main where

import           Flowbox.Graphics.Mockup as Mockup
import qualified Flowbox.Math.Matrix as M
import qualified Data.Array.Accelerate as A hiding (fromIntegral)
import           Data.Array.Accelerate.IO
import           Data.ByteString hiding (head)
import           Data.VectorSpace
--import           Diagrams.Prelude hiding (Path)
--import           Diagrams.Backend.Cairo
--import           Diagrams.Backend.Cairo.Internal
--import           Diagrams.Segment
--import           Diagrams.Trail
--import           Diagrams.TrailLike
import           Graphics.Rendering.Cairo hiding (translate)
--import           Graphics.Rendering.Cairo

import           Flowbox.Geom2D.ControlPoint
import           Flowbox.Geom2D.Path
import           Flowbox.Geom2D.Mask as Mask
import           Flowbox.Geom2D.Rasterizer hiding (makePoints, makeSegments)
import           Flowbox.Graphics.Image.IO.BMP
import           Flowbox.Graphics.Color.RGBA as Color
import qualified Data.Array.Accelerate.CUDA as CUDA
import           Flowbox.Math.Function.Accelerate.BSpline
import qualified Flowbox.Graphics.Composition.Color as Color
import           Flowbox.Graphics.Color.Color as Color
import           Flowbox.Graphics.Image.View as View
import           Data.Maybe
import           Flowbox.Graphics.Image.Channel
import           Flowbox.Prelude as P hiding (lookup)
import           Flowbox.Graphics.Image.Image
import qualified Flowbox.Graphics.Mockup as Mockup
import           Flowbox.Math.Function.Accelerate.BSpline as BSpline
import           Flowbox.Math.Function.CurveGUI as CurveGUI

generateConstantCurve :: Double -> [Point2 Double]
generateConstantCurve n = P.map (\x -> Point2 x n) (P.take 6 $ iterate (+1) 0.0)

-- for the testing purpoese only
hueCorrectLuna' :: BSpline.BSpline Double -> BSpline.BSpline Double ->
                   BSpline.BSpline Double -> BSpline.BSpline Double -> BSpline.BSpline Double ->
                   BSpline.BSpline Double -> BSpline.BSpline Double-> BSpline.BSpline Double ->
                   Image -> Image
hueCorrectLuna' lum sat r g b rSup gSup bSup img = Mockup.onEachColorRGB (Color.hueCorrect lum sat r g b rSup gSup bSup) img

conversionToBSplineTest1 :: IO ()
conversionToBSplineTest1 = do
    let h = CurveGUI.Linear
    let curve = BezierCurve [ CurveGUI.ControlPoint (Point2 0.0 1.0) h h
                            , CurveGUI.ControlPoint (Point2 1.0 2.0) h h
                            , CurveGUI.ControlPoint (Point2 2.0 1.0) h h
                            , CurveGUI.ControlPoint (Point2 3.0 2.0) h h
                            , CurveGUI.ControlPoint (Point2 4.0 1.0) h h
                            , CurveGUI.ControlPoint (Point2 5.0 2.0) h h ]

    let bSpline = CurveGUI.convertToBSpline curve
    print (A.toList bSpline)

    let v = [ valueAt (A.use bSpline) (A.constant 1.5)
              ,valueAt (A.use bSpline) (A.constant 2.0)
              ,valueAt (A.use bSpline) (A.constant 2.7) ]

    let u = P.map (head . A.toList . CUDA.run . A.unit) v

    print u

conversionToBSplineTest2 :: IO ()
conversionToBSplineTest2 = do
    let h = CurveGUI.NonLinear 0.5 0.0
    let curve = BezierCurve [ CurveGUI.ControlPoint (Point2 0.0 2.0) h h
                             , CurveGUI.ControlPoint (Point2 1.0 2.0) h h
                             , CurveGUI.ControlPoint (Point2 2.0 2.0) h h
                             , CurveGUI.ControlPoint (Point2 3.0 2.0) h h
                             , CurveGUI.ControlPoint (Point2 4.0 2.0) h h
                             , CurveGUI.ControlPoint (Point2 5.0 2.0) h h ]
    let bSpline = CurveGUI.convertToBSpline curve

    print (A.toList bSpline)

    let v = [ valueAt (A.use bSpline) (A.constant 1.2)
              ,valueAt (A.use bSpline) (A.constant 3.0)
              ,valueAt (A.use bSpline) (A.constant 4.5) ]

    let u = P.map (head . A.toList . CUDA.run . A.unit) v

    print u

conversionToBSplineTest3 :: IO ()
conversionToBSplineTest3 = do
    let h = CurveGUI.Linear
    let h2 = CurveGUI.NonLinear 1.0 (pi/4)
    let curve = BezierCurve [CurveGUI.ControlPoint (Point2 0.0 0.0) h2 h]
    let bSpline = CurveGUI.convertToBSpline curve

    let v = [ valueAt (A.use bSpline) (A.constant (-0.5))
              ,valueAt (A.use bSpline) (A.constant 0.5)
              ,valueAt (A.use bSpline) (A.constant 0.0) ]
    print (A.toList bSpline)

    let u = P.map (head . A.toList . CUDA.run . A.unit) v

    print u

conversionToBSplineTest4 :: IO ()
conversionToBSplineTest4 = do
    let h = CurveGUI.Linear
    let curve = BezierCurve [CurveGUI.ControlPoint (Point2 0.0 0.0) h h]
    let bSpline = CurveGUI.convertToBSpline curve

    let v = [ valueAt (A.use bSpline) (A.constant (1.0))
              ,valueAt (A.use bSpline) (A.constant 0.0)
              ,valueAt (A.use bSpline) (A.constant 1.0) ]

    print (A.toList bSpline)

    let u = P.map (head . A.toList . CUDA.run . A.unit) v

    print u

main :: IO ()
main = do
    print "- - - = = =   HueCorrect Test  = = = - - -"

    img <- loadImageLuna "lena.png"

    let c1 = P.map (\x -> BSplineNode x x x) $ generateConstantCurve 1.5
    let c2 = P.map (\x -> BSplineNode x x x) $ generateConstantCurve 1.0
    let c3 = P.map (\x -> BSplineNode x x x) $ generateConstantCurve 0.4
    let c4 = P.map (\x -> BSplineNode x x x) $ generateConstantCurve 0.0
    let c5 = P.map (\x -> BSplineNode (x+0.5) x (x-0.5)) $ generateConstantCurve 1.5006

    let spline1 = A.fromList (A.Z A.:. 6) c1 :: A.Vector (BSplineNode Double)
    let spline2 = A.fromList (A.Z A.:. 6) c2 :: A.Vector (BSplineNode Double)
    let spline3 = A.fromList (A.Z A.:. 6) c3 :: A.Vector (BSplineNode Double)
    let spline4 = A.fromList (A.Z A.:. 6) c4 :: A.Vector (BSplineNode Double)
    let spline5 = A.fromList (A.Z A.:. 6) c5 :: A.Vector (BSplineNode Double)

    print "tranformed image"
    let img2 = hueCorrectLuna' spline1 spline2 spline2 spline2 spline2 spline2 spline2 spline2 img
    let img3 = hueCorrectLuna' spline2 spline2 spline1 spline1 spline2 spline3 spline2 spline2 img
    let img4 = hueCorrectLuna' spline2 spline2 spline2 spline2 spline2 spline1 spline2 spline1 img
    let img5 = hueCorrectLuna' spline2 spline3 spline2 spline2 spline2 spline2 spline1 spline2 img
    let img6 = hueCorrectLuna' spline2 spline2 spline4 spline2 spline2 spline4 spline2 spline2 img
    let img7 = hueCorrectLuna' spline2 spline2 spline2 spline2 spline2 spline2 spline2 spline2 img
    let img8 = hueCorrectLuna' spline2 spline1 spline3 spline3 spline3 spline1 spline1 spline1 img

    saveImageLuna "sat_applied2.png" img2
    saveImageLuna "r_g_applied2.png" img3
    saveImageLuna "rsup_bsup_applied2.png" img4
    saveImageLuna "lum_applied2.png" img5
    saveImageLuna "r_rsup_applied2.png" img6
    saveImageLuna "id2.png" img7
    saveImageLuna "all_applied2.png" img8

    conversionToBSplineTest1
    conversionToBSplineTest2
    conversionToBSplineTest3
    conversionToBSplineTest4

    print "done"
