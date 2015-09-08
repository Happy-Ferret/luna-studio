---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}

module Luna.Interpreter.Cmd where

import Flowbox.Bus.Data.Prefix (Prefix)
import Flowbox.Prelude



data Cmd = Run { _prefix  :: Prefix
               , _verbose :: Int
               , _noColor :: Bool
               , _monitor :: Int
               }
         | Version
         deriving Show


makeLenses ''Cmd
