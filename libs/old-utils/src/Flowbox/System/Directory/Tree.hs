---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.System.Directory.Tree where

import           Flowbox.Prelude



data DirTree a = Dir  { name :: String, contents :: [DirTree a] }
               | File { name :: String, body     :: a           }
               deriving (Show)

