---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Luna.DEP.Distribution.Cabal.Config where

import           Data.Version (Version)
import qualified Data.Version as Version

import           Data.String.Utils                   (join)
import           Flowbox.Prelude
import           Luna.DEP.Distribution.Cabal.Section (Section)
import qualified Luna.DEP.Distribution.Cabal.Section as Section



data Config = Config { name         :: String
                     , version      :: Version
                     , cabalVersion :: String
                     , buildType    :: String
                     , sections     :: [Section]
                     } deriving (Show)


make :: String -> Version -> Config
make name' version' = Config name' version' ">= 1.8" "Simple" []


defaultIndent :: String
defaultIndent = replicate 18 ' '


genField :: String -> String -> String
genField name' value = name' ++ ":" ++ replicate (18 - length name') ' ' ++ value ++ "\n"


genCode :: Config -> String
genCode conf =  genField "Name"          (name conf)
             ++ genField "Version"       (Version.showVersion $ version conf)
             ++ genField "Cabal-Version" (cabalVersion conf)
             ++ genField "Build-Type"    (buildType conf)
             ++ "\n" ++  join "\n\n" (map Section.genCode $ sections conf)


addSection :: Section -> Config -> Config
addSection s conf = conf { sections = s:sections conf }
