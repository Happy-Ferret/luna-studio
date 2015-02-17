---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ViewPatterns #-}

module Flowbox.Geom2D.CubicBezier.Solve where

import           Math.BernsteinPoly
import           Geom2D
import qualified Geom2D.CubicBezier.Basic        as Cubic
import qualified Geom2D.CubicBezier.Intersection as Cubic

import Flowbox.Geom2D.CubicBezier
import Flowbox.Geom2D.CubicBezier.Conversion
import Flowbox.Prelude



valueAtX :: Int -> Float -> CubicBezier Float -> Float -> Float
valueAtX limit eps (fcb2gcb -> curve) x = solvey $
    if x <= x1 || err x1 <= eps
        then 0
        else if x >= x4 || err x4 <= eps
            then 1
            else mid $ find 0 startAt
    where Cubic.CubicBezier (Point (realToFrac -> x1) _) _ _ (Point (realToFrac -> x4) _) = curve
          startAt    = (0, 1)
          solvex t   = realToFrac $ pointX $ eval t
          solvey t   = realToFrac $ pointY $ eval t
          eval       = Cubic.evalBezier curve
          err x'     = abs $ x - x'
          mid (a, b) = (a + b) / 2
          find s t@(a, b)
              | s > limit || err x' <= eps = t
              | otherwise = find (s+1) (if x < x' then (a, m) else (m, b))
              where m  = mid t
                    x' = solvex m

findDerivRoots :: CubicBezier Float -> Float -> Float -> Float -> [Float]
findDerivRoots curve boundLo boundHi eps = uncurry (++) roots
    where roots    = over each bfr bern'
          bfr poly = realToFrac <$> Cubic.bezierFindRoot poly (realToFrac boundLo) (realToFrac boundHi) (realToFrac eps)
          bern' = over each bernsteinDeriv bern
          bern = Cubic.bezierToBernstein $ fcb2gcb curve
