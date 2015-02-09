---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Luna.Interpreter.RPC.Handler.Var where

import qualified Flowbox.Batch.Handler.Common            as Batch
import           Flowbox.Bus.RPC.RPC                     (RPC)
import           Flowbox.Prelude                         hiding (Context)
import           Flowbox.ProjectManager.Context          (Context)
import qualified Luna.DEP.Graph.Node                     as Node
import           Luna.DEP.Graph.Node.Expr                (NodeExpr)
import qualified Luna.DEP.Graph.PropertyMap              as PropertyMap
import qualified Luna.DEP.Graph.View.Default.DefaultsMap as DefaultsMap
import qualified Luna.DEP.Lib.Lib                        as Lib
import qualified Luna.DEP.Lib.Manager                    as LibManager
import qualified Luna.DEP.Pass.Analysis.ID.ExtractIDs    as ExtractIDs
import           Luna.Interpreter.RPC.Handler.Lift
import qualified Luna.Interpreter.Session.Cache.Cache    as Cache
import           Luna.Interpreter.Session.Data.CallPoint (CallPoint (CallPoint))
import qualified Luna.Interpreter.Session.Env            as Env
import           Luna.Interpreter.Session.Memory.Manager (MemoryManager)
import           Luna.Interpreter.Session.Session        (SessionST)
import qualified Luna.Interpreter.Session.Var            as Var



insertTimeRef :: Lib.ID -> Node.ID -> Node.ID
              -> NodeExpr -> RPC Context (SessionST mm) ()
insertTimeRef libraryID nodeID defID defExpr = liftSession $ do
    Env.insertDependentNode (CallPoint libraryID nodeID) defID
    when (Var.containsTimeRefs defExpr) $
        Env.insertTimeRef (CallPoint libraryID defID)


deleteTimeRef :: MemoryManager mm
              => Lib.ID -> Node.ID -> Node.ID
              -> NodeExpr -> RPC Context (SessionST mm) ()
deleteTimeRef libraryID nodeID defID defExpr = liftSession $ do
    Cache.deleteNode libraryID defID
    Env.deleteDependentNode (CallPoint libraryID nodeID) defID
    when (Var.containsTimeRefs defExpr) $
        Env.deleteTimeRef (CallPoint libraryID defID)


rebuildTimeRefs :: RPC Context (SessionST mm) ()
rebuildTimeRefs = do
    activeProjectID <- liftSession Env.getProjectID
    libManager      <- Batch.getLibManager activeProjectID
    let libraries = LibManager.labNodes libManager
        procLibs (libraryID, library) = mapM (procDM libraryID) $ PropertyMap.getDefaultsMaps $ library ^. Lib.propertyMap
        procDM libraryID (nodeID, defaultsMap) = mapM_ (process libraryID nodeID) $ DefaultsMap.elems defaultsMap
        process libraryID nodeID (defID, defExpr) = insertTimeRef libraryID nodeID defID defExpr
    liftSession Env.cleanTimeRefs
    mapM_ procLibs libraries
