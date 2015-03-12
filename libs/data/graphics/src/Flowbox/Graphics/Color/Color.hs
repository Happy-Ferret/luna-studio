---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Flowbox.Graphics.Color.Color (
    --module Flowbox.Graphics.Color.Color,
    module X,
    ColorMult(..),
    toRGBAColorMult
) where

import Flowbox.Graphics.Color.CMY                 as X
import Flowbox.Graphics.Color.CMY.Conversion      as X
import Flowbox.Graphics.Color.CMYK                as X
import Flowbox.Graphics.Color.CMYK.Conversion     as X
import Flowbox.Graphics.Color.Conversion          as X
import Flowbox.Graphics.Color.HSL                 as X
import Flowbox.Graphics.Color.HSL.Conversion      as X
import Flowbox.Graphics.Color.HSV                 as X
import Flowbox.Graphics.Color.HSV.Conversion      as X
import Flowbox.Graphics.Color.RGB                 as X
import Flowbox.Graphics.Color.RGB.Conversion      as X
import Flowbox.Graphics.Color.RGBA                as X
import Flowbox.Graphics.Color.RGBA.Conversion     as X
import Flowbox.Graphics.Color.YCbCr               as X
import Flowbox.Graphics.Color.YCbCr.Conversion    as X
import Flowbox.Graphics.Color.YCbCr_HD            as X
import Flowbox.Graphics.Color.YCbCr_HD.Conversion as X

import Flowbox.Prelude

-- TODO: LAB color space

data ColorMult a = ColorMult { _color      :: a
                             , _multiplier :: Float
                             }
                 deriving Show

toRGBAColorMult :: ColorMult (RGBA Float) -> RGBA Float
toRGBAColorMult (ColorMult color mult) = color & each %~ (*mult)
