---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleInstances #-}

module Flowbox.System.Console.StyledText.StyledText where

import           GHC.IO.Handle.Types (Handle)
import qualified System.Console.ANSI as ANSI
import           System.IO           (stderr, stdout)

import           Flowbox.Prelude                         hiding (print)
import           Flowbox.System.Console.StyledText.Style (Style (Style))
import qualified Flowbox.System.Console.StyledText.Style as Style
import qualified Data.Text.Lazy                          as Text

data Element = TextElement Text
             | StylePush Style
             | StylePop
             deriving (Show)

type StyledText = [Element]


print :: StyledText -> IO ()
print = hPrintStack stdout []

printErr :: StyledText -> IO ()
printErr = hPrintStack stderr []

hPrintStack :: Handle -> [Style] -> StyledText -> IO ()
hPrintStack _ _ []     = putStrLn ""
hPrintStack handler stack (x:xs) = case x of
    TextElement txt    -> putStr (Text.unpack txt) *> printStack stack xs
    StylePush s        -> ANSI.hSetSGR handler (Style.toSGR s) *> printStack (s:stack) xs
    StylePop           -> case stack of
                          _:s:ss -> ANSI.hSetSGR handler (Style.toSGR s)             *> printStack (s:ss) xs
                          [_]    -> ANSI.hSetSGR handler (Style.toSGR Style.Reset) *> printStack [] xs
                          []     -> printStack [] xs
    where printStack = hPrintStack handler


clearFormatting :: StyledText -> StyledText
clearFormatting [] = []
clearFormatting (x:xs) = case x of
    TextElement _ -> x : clearFormatting xs
    _             -> clearFormatting xs




beginBlack :: StyledText
beginBlack = [StylePush $ Style Style.Foreground Style.Vivid Style.Black]

beginRed :: StyledText
beginRed = [StylePush $ Style Style.Foreground Style.Vivid Style.Red]

beginGreen :: StyledText
beginGreen = [StylePush $ Style Style.Foreground Style.Vivid Style.Green]

beginYellow :: StyledText
beginYellow = [StylePush $ Style Style.Foreground Style.Vivid Style.Yellow]

beginBlue :: StyledText
beginBlue = [StylePush $ Style Style.Foreground Style.Vivid Style.Blue]

beginMagenta :: StyledText
beginMagenta = [StylePush $ Style Style.Foreground Style.Vivid Style.Magenta]

beginCyan :: StyledText
beginCyan = [StylePush $ Style Style.Foreground Style.Vivid Style.Cyan]

beginWhite :: StyledText
beginWhite = [StylePush $ Style Style.Foreground Style.Vivid Style.White]

resetColor :: StyledText
resetColor = [StylePush Style.Reset]

popColor :: StyledText
popColor = [StylePop]

black :: StyledText -> StyledText
black s = beginBlack ++ s ++ popColor

red :: StyledText -> StyledText
red s = beginRed ++ s ++ popColor

green :: StyledText -> StyledText
green s = beginGreen ++ s ++ popColor

yellow :: StyledText -> StyledText
yellow s = beginYellow ++ s ++ popColor

blue :: StyledText -> StyledText
blue s = beginBlue ++ s ++ popColor

magenta :: StyledText -> StyledText
magenta s = beginMagenta ++ s ++ popColor

cyan :: StyledText -> StyledText
cyan s = beginCyan ++ s ++ popColor

white :: StyledText -> StyledText
white s = beginWhite ++ s ++ popColor


------------------------------------------------------------------------
-- INSTANCES
------------------------------------------------------------------------

instance IsString Element where
    fromString s = TextElement (fromString s)

instance IsString StyledText where
    fromString "" = []
    fromString s  = [fromString s]

instance ToText StyledText where
    toText [] = ""
    toText (x:xs) = case x of
        TextElement txt -> txt ++ toText xs
        _               -> toText xs


