---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE RankNTypes #-}

module Flowbox.Batch.Handler.Graph where

import Control.Monad (forM_)

import           Flowbox.Batch.Batch            (Batch)
import qualified Flowbox.Batch.Handler.Common   as Batch
import qualified Flowbox.Batch.Project.Project  as Project
import           Flowbox.Control.Error          (assertE)
import           Flowbox.Prelude                hiding (error)
import           Flowbox.System.Log.Logger
import           Luna.AST.Control.Crumb         (Breadcrumbs)
import           Luna.Graph.Node                (Node)
import qualified Luna.Graph.Node                as Node
import qualified Luna.Graph.Node.OutputName     as OutputName
import qualified Luna.Graph.PropertyMap         as PropertyMap
import           Luna.Graph.View.EdgeView       (EdgeView (EdgeView))
import           Luna.Graph.View.GraphView      (GraphView)
import qualified Luna.Graph.View.GraphView      as GraphView
import           Luna.Graph.View.PortDescriptor (PortDescriptor)
import qualified Luna.Lib.Lib                   as Library



loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.Batch.Handler.Graph"


nodesGraph :: Breadcrumbs -> Library.ID -> Project.ID -> Batch GraphView
nodesGraph bc libID projectID = fst <$> Batch.getGraphView bc libID projectID


nodeByID :: Node.ID -> Breadcrumbs -> Library.ID -> Project.ID -> Batch Node
nodeByID = Batch.getNode


addNode :: Node -> Breadcrumbs -> Library.ID -> Project.ID -> Batch Node.ID
addNode node bc libID projectID = do
    (graph, propertyMap) <- Batch.getGraphView bc libID projectID
    maxID <- Batch.getMaxID libID projectID
    let newID     = maxID + 1
        fixedNode = OutputName.fixEmpty node newID
        newGraph  = GraphView.insNode (newID, fixedNode) graph
    Batch.setGraphView (newGraph, propertyMap) bc libID projectID
    Batch.safeInterpretLibrary libID projectID
    return newID


updateNode :: (Node.ID, Node) -> Breadcrumbs -> Library.ID -> Project.ID -> Batch Node.ID
updateNode (nodeID, newNode) bc libID projectID = do
    (graph, propertyMap) <- Batch.getGraphView bc libID projectID
    maxID                <- Batch.getMaxID libID projectID
    let newID     = maxID + 1
        fixedNode = OutputName.fixEmpty newNode newID
        newGraph  = GraphView.replaceNode (newID, fixedNode) nodeID graph
        newPropertyMap = PropertyMap.move nodeID newID propertyMap
    Batch.setGraphView (newGraph, newPropertyMap) bc libID projectID
    Batch.safeInterpretLibrary libID projectID
    return newID


updateNodeInPlace :: (Node.ID, Node) -> Breadcrumbs -> Library.ID -> Project.ID -> Batch ()
updateNodeInPlace (nodeID, newNode) bc libID projectID = Batch.graphViewOp bc libID projectID $ \graph propertyMap -> do
    let fixedNode = OutputName.fixEmpty newNode nodeID
        newGraph  = GraphView.updateNode (nodeID, fixedNode) graph
    return ((newGraph, propertyMap), ())


removeNodes :: [Node.ID] -> Breadcrumbs -> Library.ID -> Project.ID -> Batch ()
removeNodes nodeIDs bc libID projectID = do
    (graph, propertyMap) <- Batch.getGraphView bc libID projectID
    forM_ nodeIDs (\nodeID -> (nodeID >= 0 && GraphView.gelem nodeID graph) `assertE` ("Wrong 'nodeID' = " ++ show nodeID))
    let newGraph = GraphView.delNodes nodeIDs graph
        newPropertyMap = foldl (flip PropertyMap.delete) propertyMap nodeIDs
    Batch.setGraphView (newGraph, newPropertyMap) bc libID projectID
    Batch.safeInterpretLibrary libID projectID


connect :: Node.ID -> PortDescriptor -> Node.ID -> PortDescriptor
        -> Breadcrumbs -> Library.ID -> Project.ID -> Batch ()
connect srcNodeID srcPort dstNodeID dstPort bc libID projectID = do
    (graph, propertyMap) <- Batch.getGraphView bc libID projectID
    GraphView.gelem srcNodeID graph `assertE` ("Unable to connect: Wrong 'srcNodeID' = " ++ show srcNodeID)
    GraphView.gelem dstNodeID graph `assertE` ("Unable to connect: Wrong 'dstNodeID' = " ++ show dstNodeID)
    GraphView.isNotAlreadyConnected graph dstNodeID dstPort `assertE` "Unable to connect: Port is already connected"
    let newGraph = GraphView.insEdge (srcNodeID, dstNodeID, EdgeView srcPort dstPort) graph
    Batch.setGraphView (newGraph, propertyMap) bc libID projectID
    Batch.safeInterpretLibrary libID projectID


disconnect :: Node.ID -> PortDescriptor -> Node.ID -> PortDescriptor
           -> Breadcrumbs -> Library.ID -> Project.ID -> Batch ()
disconnect srcNodeID srcPort dstNodeID dstPort bc libID projectID = do
    (graph, propertyMap) <- Batch.getGraphView bc libID projectID
    GraphView.gelem srcNodeID graph `assertE` ("Wrong 'srcNodeID' = " ++ show srcNodeID)
    GraphView.gelem dstNodeID graph `assertE` ("Wrong 'dstNodeID' = " ++ show dstNodeID)
    let newGraph = GraphView.delLEdge (srcNodeID, dstNodeID, EdgeView srcPort dstPort) graph
    Batch.setGraphView (newGraph, propertyMap) bc libID projectID
    Batch.safeInterpretLibrary libID projectID
