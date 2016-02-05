---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
module Flowbox.Options.Applicative (
    module Options.Applicative,
    optIntFlag,
) where

import           Options.Applicative

import           Flowbox.Prelude



optIntFlag :: Maybe String -> Char -> Int -> Int -> String -> Parser Int
optIntFlag mlongName shortName baseval defval helpmsg =
    (\sflag f -> let baselvl = if sflag then defval else baseval
                     explvl  = read f :: Int
                     lvl     = if explvl < 0 then baselvl else explvl
                 in lvl
    )
    <$> switch    ( longName <> short shortName <> help helpmsg )
    <*> strOption ( short shortName <> value "-1" <> hidden     ) where
    longName = case mlongName of
        Just n  -> long n
        Nothing -> idm


