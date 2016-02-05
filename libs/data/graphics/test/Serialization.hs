---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.ByteString.Lazy.Char8
import           Flowbox.Prelude                              hiding (putStrLn, view)

import           Flowbox.Graphics.Image.Channel               hiding (compute)
import           Flowbox.Graphics.Image.View                  as V
import           Flowbox.Graphics.Serialization               ()

import qualified Data.Array.Accelerate                        as A
import           Flowbox.Data.Mode                            ()
import           Flowbox.Data.Serialization                   (toValue)
import           Flowbox.Graphics.Composition.Generator.Shape
import           Flowbox.Graphics.Shader.Matrix
import           Flowbox.Graphics.Shader.Rasterizer
import           Flowbox.Graphics.Shader.Stencil              as Stencil
import           Flowbox.Graphics.Utils.Accelerate            (variable)
import           Text.ProtocolBuffers.WireMessage

import           Utils

--
-- applies defocus to the lena image and serializes it to the ByteString
-- (Serialization test)
--
defocusSerialize :: A.Exp Int -> IO ()
defocusSerialize blurSize = do
    -- Load from file
    (r, g, b, a) <- testLoadRGBA' "samples/lena_micro.bmp"

    -- Apply defocus blur
    let kern = ellipse (pure $ variable blurSize) 1 0
    let process x = rasterizer $ normStencil (+) kern (+) 0 $ fromMatrix A.Clamp x

    let red   = ChannelFloat "r" (MatrixData $ process r) -- process introduces delayed computation
    let green = ChannelFloat "g" (MatrixData $ process g)
    let blue  = ChannelFloat "b" (MatrixData $ process b)
    let alpha = ChannelFloat "a" (MatrixData $ process a)

    -- Construct a view
    let view :: View
        view = V.append alpha
             $ V.append blue
             $ V.append green
             $ V.append red
             $ V.empty "lena"

    -- Try to serialize the uncomputed array
    --try1 <- toValue view def
    --case try1 of
    --    Just _ -> putStrLn "Magic happened! We have a value from an uncomputed array"
    --    Nothing -> do
    --        try2 <- toValue (compute view def) def -- Try to serialize the computed array
    --        case try2 of
    --            Just msg -> putStrLn $ messagePut msg
    --            Nothing -> putStrLn "Something went wrong"
    return ()

main :: IO ()
main = defocusSerialize 10

