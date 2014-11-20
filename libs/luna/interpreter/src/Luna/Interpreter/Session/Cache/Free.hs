---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Flowbox Team <contact@flowbox.io>, 2014
-- Proprietary and confidential
-- Unauthorized copying of this file, via any medium is strictly prohibited
---------------------------------------------------------------------------
module Luna.Interpreter.Session.Cache.Free where

import qualified Data.Map as Map

import           Flowbox.Prelude
import           Luna.Interpreter.Session.Cache.Info        (CacheInfo)
import qualified Luna.Interpreter.Session.Cache.Info        as CacheInfo
import           Luna.Interpreter.Session.Data.VarName      (VarName)
import           Luna.Interpreter.Session.Session           (Session)
import qualified Luna.Interpreter.Session.TargetHS.Bindings as Bindings



freeVarName :: VarName -> Session ()
freeVarName varName = lift2 $
    --Session.runAssignment varName "()"
    Bindings.remove varName
    --Bindings.remove "_tmp"
    --Bindings.remove "it"


freeCacheInfo :: CacheInfo -> Session ()
freeCacheInfo cacheInfo =
    mapM_ freeVarName $ Map.elems $ cacheInfo ^. CacheInfo.dependencies
