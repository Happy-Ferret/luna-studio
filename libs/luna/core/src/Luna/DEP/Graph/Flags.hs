---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}

module Luna.DEP.Graph.Flags where

import           Flowbox.Prelude
import qualified Luna.DEP.AST.Common          as AST
import           Luna.DEP.Graph.Node.Position (Position)



data Flags = Flags { _omit                 :: Bool
                   , _astFolded            :: Maybe Bool
                   , _astAssignment        :: Maybe Bool
                   , _graphFoldInfo        :: Maybe FoldInfo
                   , _grouped              :: Maybe Bool
                   , _defaultNodeGenerated :: Maybe Bool
                   , _defaultNodeOriginID  :: Maybe Int
                   , _graphViewGenerated   :: Maybe Bool
                   , _nodePosition         :: Maybe Position
                   } deriving (Show, Read, Eq)


data FoldInfo = Folded
              | FoldTop { _id :: AST.ID }
              deriving (Show, Read, Eq)


makeLenses ''Flags
makeLenses ''FoldInfo


instance Default Flags where
    def = Flags False Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing


isSet' :: Flags -> (Flags -> Maybe Bool) -> Bool
isSet' flags getter = getter flags == Just True


isFolded :: Flags -> Bool
isFolded flags = flags ^. graphFoldInfo == Just Folded


isDefaultNodeGenerated :: Flags -> Bool
isDefaultNodeGenerated = flip isSet' (view defaultNodeGenerated)

getFoldTop :: Flags -> Maybe AST.ID
getFoldTop flags = case flags ^. graphFoldInfo of
    Just (FoldTop i) -> Just i
    _                -> Nothing
