---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Luna.DEP.Pass.Transform.GraphView.Defaults (
    addDefaults,
    removeDefaults,
    isGenerated,
) where

import qualified Data.Map as Map

import           Flowbox.Control.Error              ()
import           Flowbox.Prelude                    hiding (empty)
import qualified Luna.DEP.Graph.Flags               as Flags
import qualified Luna.DEP.Graph.Node                as Node
import qualified Luna.DEP.Graph.Node.OutputName     as OutputName
import           Luna.DEP.Graph.Properties          (Properties)
import qualified Luna.DEP.Graph.Properties          as Properties
import           Luna.DEP.Graph.PropertyMap         (PropertyMap)
import qualified Luna.DEP.Graph.PropertyMap         as PropertyMap
import           Luna.DEP.Graph.View.Default.Expr   (DefaultExpr (DefaultExpr))
import           Luna.DEP.Graph.View.EdgeView       (EdgeView (EdgeView))
import           Luna.DEP.Graph.View.GraphView      (GraphView)
import qualified Luna.DEP.Graph.View.GraphView      as GraphView
import           Luna.DEP.Graph.View.PortDescriptor (PortDescriptor)



generateProperties :: Node.ID -> Properties
generateProperties originID = def & Properties.flags . Flags.defaultNodeGenerated .~ Just True
                                  & Properties.flags . Flags.defaultNodeOriginID  .~ Just originID


addDefaults :: GraphView -> PropertyMap -> (GraphView, PropertyMap)
addDefaults graph propertyMap =
    foldr addNodeDefaults (graph, propertyMap) $ GraphView.nodes graph


addNodeDefaults :: Node.ID -> (GraphView, PropertyMap) -> (GraphView, PropertyMap)
addNodeDefaults nodeID gp@(_, propertyMap) =
    foldr (addNodeDefault nodeID) gp defaults
    where
        defaults = Map.toList $ PropertyMap.getDefaultsMap nodeID propertyMap


addNodeDefault :: Node.ID -> (PortDescriptor, DefaultExpr) -> (GraphView, PropertyMap) -> (GraphView, PropertyMap)
addNodeDefault nodeID (adstPort, DefaultExpr defaultNodeID defaultOriginID defaultValue) (graph, propertyMap) =
    if GraphView.isNotAlreadyConnected graph nodeID adstPort
        then (newGraph2, newPropertyMap)
        else (graph, propertyMap)
    where
      node      = OutputName.provide (Node.Expr defaultValue "" (0, 0)) nodeID
      newGraph  = GraphView.insNode (defaultNodeID, node) graph
      newGraph2 = GraphView.insEdge (defaultNodeID, nodeID, EdgeView [] adstPort) newGraph
      newPropertyMap = PropertyMap.insert defaultNodeID (generateProperties defaultOriginID) propertyMap


isGenerated :: Node.ID -> PropertyMap -> Bool
isGenerated nodeID propertyMap =
    Flags.isSet' (PropertyMap.getFlags nodeID propertyMap) (view Flags.defaultNodeGenerated)


delGenerated :: Node.ID -> (GraphView, PropertyMap) -> (GraphView, PropertyMap)
delGenerated nodeID gp@(graph, propertyMap) = if isGenerated nodeID propertyMap
    then (GraphView.delNode nodeID graph, PropertyMap.delete nodeID propertyMap)
    else gp


removeDefaults :: GraphView -> PropertyMap -> (GraphView, PropertyMap)
removeDefaults graph propertyMap = foldr delGenerated (graph, propertyMap) $ GraphView.nodes graph
