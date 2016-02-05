---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell  #-}

module Luna.DEP.Pass.Transform.AST.Desugar.General.State where

import           Luna.DEP.Data.ASTInfo     (ASTInfo)
import qualified Luna.DEP.Data.ASTInfo     as ASTInfo

import           Flowbox.Prelude           hiding (id)
import           Flowbox.System.Log.Logger hiding (info)

import           Control.Monad.State       (MonadState, get, modify)

logger :: Logger
logger = getLogger $moduleName

type ID = Int

data DesugarState = DesugarState { _info :: ASTInfo
                                 }
                  deriving (Show)

makeLenses (''DesugarState)

type DesugarMonad m = (MonadState DesugarState m, Applicative m)


getInfo :: DesugarMonad m => m ASTInfo
getInfo = view info <$> get

incID :: DesugarMonad m => m ()
incID = modify ((info . ASTInfo.lastID) %~ (+1))

genID :: DesugarMonad m => m ID
genID = (view (info . ASTInfo.lastID) <$> get) <* incID


mk :: ASTInfo -> DesugarState
mk = DesugarState

------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------

instance Default DesugarState where
    def = DesugarState def
