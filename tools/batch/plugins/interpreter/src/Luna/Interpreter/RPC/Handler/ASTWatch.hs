---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
module Luna.Interpreter.RPC.Handler.ASTWatch where

import qualified Flowbox.Batch.Handler.Common                                                                  as Batch
import           Flowbox.Batch.Tools.Serialize.Proto.Conversion.Project                                        ()
import           Flowbox.Bus.RPC.RPC                                                                           (RPC)
import           Flowbox.Control.Error                                                                         hiding (err)
import           Flowbox.Data.Convert
import           Flowbox.Prelude                                                                               hiding (Context, error, op)
import           Flowbox.ProjectManager.Context                                                                (Context)
import qualified Flowbox.ProjectManager.RPC.Handler.AST                                                        as ASTHandler
import qualified Flowbox.ProjectManager.RPC.Handler.Graph                                                      as GraphHandler
import qualified Flowbox.ProjectManager.RPC.Handler.Library                                                    as LibraryHandler
import qualified Flowbox.ProjectManager.RPC.Handler.NodeDefault                                                as NodeDefaultHandler
import qualified Flowbox.ProjectManager.RPC.Handler.Project                                                    as ProjectHandler
import qualified Flowbox.ProjectManager.RPC.Handler.Properties                                                 as PropertiesHandler
import           Flowbox.System.Log.Logger
import qualified Generated.Proto.Graph.Node                                                                    as Gen.Node
import qualified Generated.Proto.Library.Library                                                               as Gen.Library
import qualified Generated.Proto.Project.Project                                                               as Gen.Project
import qualified Generated.Proto.ProjectManager.Project.Close.Request                                          as ProjectClose
import qualified Generated.Proto.ProjectManager.Project.Close.Update                                           as ProjectClose
import qualified Generated.Proto.ProjectManager.Project.Create.Update                                          as ProjectCreate
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Add.Request                           as ASTDataAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Add.Update                            as ASTDataAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Classes.Request                as ASTDataModifyClasses
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Classes.Update                 as ASTDataModifyClasses
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Cls.Request                    as ASTDataModifyCls
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Cls.Update                     as ASTDataModifyCls
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Cons.Request                   as ASTDataModifyCons
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Cons.Update                    as ASTDataModifyCons
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Methods.Request                as ASTDataModifyMethods
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Data.Modify.Methods.Update                 as ASTDataModifyMethods
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Add.Request                       as ASTFunctionAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Add.Update                        as ASTFunctionAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Connect.Request             as GraphConnect
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Connect.Update              as GraphConnect
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Disconnect.Request          as GraphDisconnect
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Disconnect.Update           as GraphDisconnect
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Add.Request            as GraphNodeAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Add.Update             as GraphNodeAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Default.Remove.Request as GraphNodeDefaultRemove
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Default.Remove.Update  as GraphNodeDefaultRemove
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Default.Set.Request    as GraphNodeDefaultSet
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Default.Set.Update     as GraphNodeDefaultSet
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Modify.Request         as GraphNodeModify
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Modify.Update          as GraphNodeModify
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.ModifyInPlace.Request  as GraphNodeModifyInPlace
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.ModifyInPlace.Update   as GraphNodeModifyInPlace
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Properties.Set.Update  as GraphNodePropertiesSet
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Remove.Request         as GraphNodeRemove
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Graph.Node.Remove.Update          as GraphNodeRemove
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Inputs.Request             as ASTFunctionModifyInputs
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Inputs.Update              as ASTFunctionModifyInputs
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Name.Request               as ASTFunctionModifyName
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Name.Update                as ASTFunctionModifyName
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Output.Request             as ASTFunctionModifyOutput
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Output.Update              as ASTFunctionModifyOutput
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Path.Request               as ASTFunctionModifyPath
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Function.Modify.Path.Update                as ASTFunctionModifyPath
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Add.Request                         as ASTModuleAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Add.Update                          as ASTModuleAdd
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Cls.Request                  as ASTModuleModifyCls
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Cls.Update                   as ASTModuleModifyCls
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Fields.Request               as ASTModuleModifyFields
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Fields.Update                as ASTModuleModifyFields
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Imports.Request              as ASTModuleModifyImports
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Module.Modify.Imports.Update               as ASTModuleModifyImports
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Properties.Set.Update                      as ASTPropertiesSet
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Remove.Request                             as ASTRemove
import qualified Generated.Proto.ProjectManager.Project.Library.AST.Remove.Update                              as ASTRemove
import qualified Generated.Proto.ProjectManager.Project.Library.Create.Request                                 as LibraryCreate
import qualified Generated.Proto.ProjectManager.Project.Library.Create.Update                                  as LibraryCreate
import qualified Generated.Proto.ProjectManager.Project.Library.Load.Request                                   as LibraryLoad
import qualified Generated.Proto.ProjectManager.Project.Library.Load.Update                                    as LibraryLoad
import qualified Generated.Proto.ProjectManager.Project.Library.Unload.Request                                 as LibraryUnload
import qualified Generated.Proto.ProjectManager.Project.Library.Unload.Update                                  as LibraryUnload
import qualified Generated.Proto.ProjectManager.Project.Modify.Update                                          as ProjectModify
import qualified Generated.Proto.ProjectManager.Project.Open.Update                                            as ProjectOpen
import           Luna.Interpreter.Proto.CallPointPath                                                          ()
import qualified Luna.Interpreter.RPC.Handler.Cache                                                            as CacheWrapper
import           Luna.Interpreter.RPC.Handler.Sync                                                             (sync)
import qualified Luna.Interpreter.RPC.Handler.Var                                                              as Var
import           Luna.Interpreter.Session.Memory.Manager                                                       (MemoryManager)
import           Luna.Interpreter.Session.Session                                                              (SessionST)



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


--- handlers --------------------------------------------------------------

projectCreate :: MemoryManager mm => ProjectCreate.Update -> RPC Context (SessionST mm) ()
projectCreate (ProjectCreate.Update request project updateNo) = do
    sync updateNo $ ProjectHandler.create request
    projectID <- Gen.Project.id project <??> "ASTWatch.projectCreate : 'projectID' field is missing"
    CacheWrapper.modifyAll projectID


projectOpen :: MemoryManager mm => ProjectOpen.Update -> RPC Context (SessionST mm) ()
projectOpen (ProjectOpen.Update _ project _) = do
    projectID <- Gen.Project.id project <??> "ASTWatch.projectOpen : 'projectID' field is missing"
    CacheWrapper.modifyAll projectID


projectClose :: ProjectClose.Update -> RPC Context (SessionST mm) ()
projectClose (ProjectClose.Update request updateNo) = do
    sync updateNo $ ProjectHandler.close request
    CacheWrapper.closeProject $ ProjectClose.projectID request


projectModify :: ProjectModify.Update -> RPC Context (SessionST mm) ()
projectModify (ProjectModify.Update request updateNo) =
    sync updateNo $ ProjectHandler.modify request


libraryCreate :: LibraryCreate.Update -> RPC Context (SessionST mm) ()
libraryCreate (LibraryCreate.Update request library updateNo) = do
    sync updateNo $ LibraryHandler.create request
    let projectID = LibraryCreate.projectID request
    libraryID <- Gen.Library.id library <??> "ASTWatch.libraryCreate : 'libraryID' field is missing"
    CacheWrapper.modifyLibrary projectID libraryID


libraryLoad :: LibraryLoad.Update -> RPC Context (SessionST mm) ()
libraryLoad (LibraryLoad.Update request library _) = do
    let projectID = LibraryLoad.projectID request
    libraryID <- Gen.Library.id library <??> "ASTWatch.libraryLoad : 'libraryID' field is missing"
    CacheWrapper.modifyLibrary projectID libraryID


libraryUnload :: LibraryUnload.Update -> RPC Context (SessionST mm) ()
libraryUnload (LibraryUnload.Update request updateNo) = do
    sync updateNo $ LibraryHandler.unload request
    let projectID = LibraryUnload.projectID request
        libraryID = LibraryUnload.libraryID request
    CacheWrapper.modifyLibrary projectID libraryID


astRemove :: ASTRemove.Update -> RPC Context (SessionST mm) ()
astRemove (ASTRemove.Update request updateNo) = do
    sync updateNo $ ASTHandler.remove request
    let projectID = ASTRemove.projectID request
        libraryID = ASTRemove.libraryID request
        bc        = ASTRemove.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astModuleAdd :: ASTModuleAdd.Update -> RPC Context (SessionST mm) ()
astModuleAdd (ASTModuleAdd.Update request _ bc updateNo) = do
    sync updateNo $ ASTHandler.moduleAdd request
    let projectID = ASTModuleAdd.projectID request
        libraryID = ASTModuleAdd.libraryID request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astModuleModifyCls :: ASTModuleModifyCls.Update -> RPC Context (SessionST mm) ()
astModuleModifyCls (ASTModuleModifyCls.Update request updateNo) = do
    sync updateNo $ ASTHandler.moduleClsModify request
    let projectID = ASTModuleModifyCls.projectID request
        libraryID = ASTModuleModifyCls.libraryID request
        bc        = ASTModuleModifyCls.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astModuleModifyFields :: ASTModuleModifyFields.Update -> RPC Context (SessionST mm) ()
astModuleModifyFields (ASTModuleModifyFields.Update request updateNo) = do
    sync updateNo $ ASTHandler.moduleFieldsModify request
    let projectID = ASTModuleModifyFields.projectID request
        libraryID = ASTModuleModifyFields.libraryID request
        bc        = ASTModuleModifyFields.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astModuleModifyImports :: ASTModuleModifyImports.Update -> RPC Context (SessionST mm) ()
astModuleModifyImports (ASTModuleModifyImports.Update request updateNo) = do
    sync updateNo $ ASTHandler.moduleImportsModify request
    let projectID = ASTModuleModifyImports.projectID request
        libraryID = ASTModuleModifyImports.libraryID request
        bc        = ASTModuleModifyImports.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astDataAdd :: ASTDataAdd.Update -> RPC Context (SessionST mm) ()
astDataAdd (ASTDataAdd.Update request _ bc updateNo) = do
    sync updateNo $ ASTHandler.dataAdd request
    let projectID = ASTDataAdd.projectID request
        libraryID = ASTDataAdd.libraryID request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astDataModifyClasses :: ASTDataModifyClasses.Update -> RPC Context (SessionST mm) ()
astDataModifyClasses (ASTDataModifyClasses.Update request updateNo) = do
    sync updateNo $ ASTHandler.dataClassesModify request
    let projectID = ASTDataModifyClasses.projectID request
        libraryID = ASTDataModifyClasses.libraryID request
        bc        = ASTDataModifyClasses.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc

astDataModifyCls :: ASTDataModifyCls.Update -> RPC Context (SessionST mm) ()
astDataModifyCls (ASTDataModifyCls.Update request updateNo) = do
    sync updateNo $ ASTHandler.dataClsModify request
    let projectID = ASTDataModifyCls.projectID request
        libraryID = ASTDataModifyCls.libraryID request
        bc        = ASTDataModifyCls.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astDataModifyCons :: ASTDataModifyCons.Update -> RPC Context (SessionST mm) ()
astDataModifyCons (ASTDataModifyCons.Update request updateNo) = do
    sync updateNo $ ASTHandler.dataConsModify request
    let projectID = ASTDataModifyCons.projectID request
        libraryID = ASTDataModifyCons.libraryID request
        bc        = ASTDataModifyCons.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc

astDataModifyMethods :: ASTDataModifyMethods.Update -> RPC Context (SessionST mm) ()
astDataModifyMethods (ASTDataModifyMethods.Update request updateNo) = do
    sync updateNo $ ASTHandler.dataMethodsModify request
    let projectID = ASTDataModifyMethods.projectID request
        libraryID = ASTDataModifyMethods.libraryID request
        bc        = ASTDataModifyMethods.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc

astFunctionAdd :: ASTFunctionAdd.Update -> RPC Context (SessionST mm) ()
astFunctionAdd (ASTFunctionAdd.Update request _ bc updateNo) = do
    sync updateNo $ ASTHandler.functionAdd request
    let projectID = ASTFunctionAdd.projectID request
        libraryID = ASTFunctionAdd.libraryID request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astFunctionModifyInputs :: ASTFunctionModifyInputs.Update -> RPC Context (SessionST mm) ()
astFunctionModifyInputs (ASTFunctionModifyInputs.Update request updateNo) = do
    sync updateNo $ ASTHandler.functionInputsModify request
    let projectID = ASTFunctionModifyInputs.projectID request
        libraryID = ASTFunctionModifyInputs.libraryID request
        bc        = ASTFunctionModifyInputs.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astFunctionModifyName :: ASTFunctionModifyName.Update -> RPC Context (SessionST mm) ()
astFunctionModifyName (ASTFunctionModifyName.Update request updateNo) = do
    sync updateNo $ ASTHandler.functionNameModify request
    let projectID = ASTFunctionModifyName.projectID request
        libraryID = ASTFunctionModifyName.libraryID request
        bc        = ASTFunctionModifyName.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astFunctionModifyOutput :: ASTFunctionModifyOutput.Update -> RPC Context (SessionST mm) ()
astFunctionModifyOutput (ASTFunctionModifyOutput.Update request updateNo) = do
    sync updateNo $ ASTHandler.functionOutputModify request
    let projectID = ASTFunctionModifyOutput.projectID request
        libraryID = ASTFunctionModifyOutput.libraryID request
        bc        = ASTFunctionModifyOutput.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astFunctionModifyPath :: ASTFunctionModifyPath.Update -> RPC Context (SessionST mm) ()
astFunctionModifyPath (ASTFunctionModifyPath.Update request updateNo) = do
    sync updateNo $ ASTHandler.functionPathModify request
    let projectID = ASTFunctionModifyPath.projectID request
        libraryID = ASTFunctionModifyPath.libraryID request
        bc        = ASTFunctionModifyPath.bc request
    CacheWrapper.modifyBreadcrumbsRec projectID libraryID bc


astPropertiesSet :: ASTPropertiesSet.Update -> RPC Context (SessionST mm) ()
astPropertiesSet (ASTPropertiesSet.Update request updateNo) =
    sync updateNo $ PropertiesHandler.setASTProperties request


graphConnect :: GraphConnect.Update -> RPC Context (SessionST mm) ()
graphConnect (GraphConnect.Update request updateNo) = do
    sync updateNo $ GraphHandler.connect request
    let projectID = GraphConnect.projectID request
        libraryID = GraphConnect.libraryID request
        dstID     = GraphConnect.dstNodeID request
    CacheWrapper.modifyNode projectID libraryID dstID


graphDisconnect :: GraphDisconnect.Update -> RPC Context (SessionST mm) ()
graphDisconnect (GraphDisconnect.Update request updateNo) = do
    sync updateNo $ GraphHandler.disconnect request
    let projectID = GraphDisconnect.projectID request
        libraryID = GraphDisconnect.libraryID request
        dstID     = GraphDisconnect.dstNodeID request
    CacheWrapper.modifyNode projectID libraryID dstID


graphNodeAdd :: GraphNodeAdd.Update -> RPC Context (SessionST mm) ()
graphNodeAdd (GraphNodeAdd.Update request node updateNo) = do
    sync updateNo $ GraphHandler.nodeAdd request
    let projectID = GraphNodeAdd.projectID request
        libraryID = GraphNodeAdd.libraryID request
    nodeID <- Gen.Node.id node <??> "ASTWatch.graphNodeAdd : 'nodeID' field is missing"
    CacheWrapper.modifyNode projectID libraryID nodeID


graphNodeRemove :: MemoryManager mm => GraphNodeRemove.Update -> RPC Context (SessionST mm) ()
graphNodeRemove (GraphNodeRemove.Update request updateNo) = do
    let projectID = GraphNodeRemove.projectID request
        libraryID = GraphNodeRemove.libraryID request
        bc        = GraphNodeRemove.bc request
        nodeIDs   = GraphNodeRemove.nodeIDs request
    mapM_ (CacheWrapper.modifyNodeSuccessors projectID libraryID bc) nodeIDs
    mapM_ (CacheWrapper.deleteNode projectID libraryID) nodeIDs
    sync updateNo $ GraphHandler.nodeRemove request


graphNodeModify :: GraphNodeModify.Update -> RPC Context (SessionST mm) ()
graphNodeModify (GraphNodeModify.Update request node updateNo) = do
    sync updateNo $ GraphHandler.nodeModify request
    let projectID = GraphNodeModify.projectID request
        libraryID = GraphNodeModify.libraryID request
    nodeID <- Gen.Node.id node <??> "ASTWatch.graphNodeModify : 'nodeID' field is missing"
    CacheWrapper.modifyNode projectID libraryID nodeID


graphNodeModifyInPlace :: GraphNodeModifyInPlace.Update -> RPC Context (SessionST mm) ()
graphNodeModifyInPlace (GraphNodeModifyInPlace.Update request updateNo) = do
    sync updateNo $ GraphHandler.nodeModifyInPlace request
    let projectID = GraphNodeModifyInPlace.projectID request
        libraryID = GraphNodeModifyInPlace.libraryID request
    nodeID <- Gen.Node.id (GraphNodeModifyInPlace.node request) <??> "ASTWatch.graphNodeModify : 'nodeID' field is missing"
    CacheWrapper.modifyNode projectID libraryID nodeID


graphNodeDefaultRemove :: GraphNodeDefaultRemove.Update -> RPC Context (SessionST mm) ()
graphNodeDefaultRemove (GraphNodeDefaultRemove.Update request updateNo) = do
    sync updateNo $ NodeDefaultHandler.remove request
    let projectID = GraphNodeDefaultRemove.projectID request
        libraryID = GraphNodeDefaultRemove.libraryID request
        nodeID    = GraphNodeDefaultRemove.nodeID request
    CacheWrapper.modifyNode projectID libraryID nodeID
    -- TODO[PM] : remove default from cache


graphNodeDefaultSet :: MemoryManager mm
                    => GraphNodeDefaultSet.Update -> RPC Context (SessionST mm) ()
graphNodeDefaultSet (GraphNodeDefaultSet.Update request updateNo) = do
    let tprojectID = GraphNodeDefaultSet.projectID request
        tlibraryID = GraphNodeDefaultSet.libraryID request
        tnodeID    = GraphNodeDefaultSet.nodeID request
        projectID  = decodeP tprojectID
        libraryID  = decodeP tlibraryID
        nodeID     = decodeP tnodeID
        inPort     = decodeP $ GraphNodeDefaultSet.inPort request
    CacheWrapper.interpreterDo' tprojectID $ do
        Batch.lookupNodeDefault inPort nodeID libraryID projectID >>= \case
            Nothing               -> return ()
            Just (defID, defExpr) -> Var.deleteTimeRef libraryID nodeID defID defExpr
        sync updateNo $ NodeDefaultHandler.set request
        Batch.lookupNodeDefault inPort nodeID libraryID projectID >>= \case
            Nothing               -> left "ASTWatch.graphNodeDefaultSet"
            Just (defID, defExpr) -> Var.insertTimeRef libraryID nodeID defID defExpr
        CacheWrapper.modifyNode tprojectID tlibraryID tnodeID


graphNodePropertiesSet :: GraphNodePropertiesSet.Update -> RPC Context (SessionST mm) ()
graphNodePropertiesSet (GraphNodePropertiesSet.Update request updateNo) =
    sync updateNo $ PropertiesHandler.setNodeProperties request
