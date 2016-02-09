{-# LANGUAGE OverloadedStrings #-}
module Reactive.Commands.AddNode
    ( addNode
    , updateNode
    , updateNodeValue
    ) where

import           Utils.PreludePlus
import           Utils.Vector

import           Control.Monad.State             hiding (State)
import qualified Data.Map.Lazy                   as Map
import qualified Data.Text.Lazy                  as Text
import           GHC.Float                       (double2Float)

import           Object.UITypes                  (WidgetId)
import           Object.Widget                   ()
import qualified Object.Widget.Button            as Button
import qualified Object.Widget.Group             as Group
import qualified Object.Widget.Label             as Label
import           Object.Widget.LabeledTextBox    (LabeledTextBox (..))
import qualified Object.Widget.LabeledTextBox    as LabeledTextBox
import qualified Object.Widget.Node              as Model
import           Object.Widget.Number.Continuous (ContinuousNumber (..))
import qualified Object.Widget.Number.Continuous as ContinuousNumber
import           Object.Widget.Number.Discrete   (DiscreteNumber (..))
import qualified Object.Widget.Number.Discrete   as DiscreteNumber
import qualified Object.Widget.Plots.ScatterPlot as ScatterPlot
import qualified Object.Widget.Port              as PortModel
import           Object.Widget.Toggle            (Toggle (..))
import qualified Object.Widget.Toggle            as Toggle
import qualified UI.Handlers.Button              as Button
import qualified UI.Handlers.LabeledTextBox      as LabeledTextBox
import qualified UI.Handlers.Node                as Node
import qualified UI.Handlers.Number.Continuous   as ContinuousNumber
import qualified UI.Handlers.Number.Discrete     as DiscreteNumber
import qualified UI.Handlers.Toggle              as Toggle

import           Reactive.Commands.Command       (Command, performIO)
import           Reactive.Commands.EnterNode     (enterNode)
import           Reactive.Commands.Graph         (focusNode, nodeIdToWidgetId, portDefaultAngle, updateNodeMeta,
                                                  updatePortAngles)
-- import           Reactive.Commands.PendingNode   (unrenderPending)
import           Reactive.Commands.RemoveNode    (removeSelectedNodes)
import qualified Reactive.Commands.UIRegistry    as UICmd
import           Reactive.State.Global           (State, inRegistry)
import qualified Reactive.State.Global           as Global
import qualified Reactive.State.Graph            as Graph
import           Reactive.State.UIRegistry       (addHandler, sceneGraphId)
import qualified Reactive.State.UIRegistry       as UIRegistry

import qualified BatchConnector.Commands         as BatchCmd
import qualified JS.NodeGraph                    as UI

import           Data.HMap.Lazy                  (HTMap)
import qualified Data.HMap.Lazy                  as HMap
import           Data.Map.Lazy                   (Map)
import qualified Data.Map.Lazy                   as Map
import           UI.Handlers.Generic             (ValueChangedHandler (..), triggerValueChanged)
import qualified UI.Handlers.Node                as UINode
import           UI.Layout                       as Layout
import qualified UI.Registry                     as UIR
import qualified UI.Scene
import qualified UI.Widget                       as UIT

import qualified Style.Node                      as Style
import qualified Style.Types                     as Style

import qualified Empire.API.Data.Breadcrumb      as Breadcrumb
import           Empire.API.Data.DefaultValue    (Value (..))
import qualified Empire.API.Data.DefaultValue    as DefaultValue
import           Empire.API.Data.Node            (Node, NodeId)
import qualified Empire.API.Data.Node            as Node
import           Empire.API.Data.Port            (InPort (..), Port (..), PortId (..))
import qualified Empire.API.Data.Port            as Port
import           Empire.API.Data.PortRef         (AnyPortRef (..), InPortRef (..), toAnyPortRef)
import           Empire.API.Data.ValueType       (ValueType (..))
import qualified Empire.API.Data.ValueType       as ValueType


addNode :: Node -> Command State ()
addNode node = do
    -- unrenderPending node
    zoom Global.graph $ modify (Graph.addNode node)
    zoom Global.uiRegistry $ registerNode node
    updatePortAngles

colorVT _ = 11
colorPort (Port.InPortId Port.Self) = 12
colorPort _ = 11

registerNode :: Node -> Command UIRegistry.State ()
registerNode node = do
    let nodeModel = Model.fromNode node
    nodeWidget <- UICmd.register sceneGraphId nodeModel (nodeHandlers node)

    displayPorts nodeWidget node
    focusNode nodeWidget


nodePorts :: WidgetId -> Command UIRegistry.State [WidgetId]
nodePorts id = do
    children <- UICmd.children id
    let isPort id = (UIRegistry.lookupTypedM id :: UIRegistry.LookupFor PortModel.Port) >>= return . isJust
    filterM isPort children

makePorts :: Node -> [PortModel.Port]
makePorts node = makePort <$> (zip [1..] $ Map.elems $ node ^. Node.ports) where
    nodeId  = node ^. Node.nodeId
    makePort (portIx, port) = PortModel.Port portRef angle (colorPort $ port ^. Port.portId ) where
        portRef = toAnyPortRef nodeId (port ^. Port.portId)
        angle   = portDefaultAngle ((length $ node ^. Node.ports) - 1) (port ^. Port.portId) portIx

displayPorts :: WidgetId -> Node -> Command UIRegistry.State ()
displayPorts id node = do
    nodeId <- UICmd.get id Model.nodeId
    oldPorts <- nodePorts id
    mapM_ UICmd.removeWidget oldPorts

    groupId <- Node.portControlsGroupId id
    portControls <- UICmd.children groupId
    mapM_ UICmd.removeWidget portControls

    let newPorts = makePorts node

    forM_ newPorts $ \p -> UICmd.register id p def
    forM_ (node ^. Node.ports) $ \p -> makePortControl groupId (node ^. Node.nodeId) p

nodeHandlers :: Node -> HTMap
nodeHandlers node = addHandler (UINode.RemoveNodeHandler removeSelectedNodes)
                  $ addHandler (UINode.RenameNodeHandler $ \_ nodeId name -> do
                      workspace <- use Global.workspace
                      performIO $ BatchCmd.renameNode workspace nodeId name)
                  $ addHandler (UINode.FocusNodeHandler  $ \id -> zoom Global.uiRegistry (focusNode id))
                  $ addEnterNodeHandler where
                        addEnterNodeHandler = case node ^. Node.nodeType of
                            Node.FunctionNode _ -> addHandler (UINode.EnterNodeHandler $ enterNode $ Breadcrumb.Function $ Text.unpack $ node ^. Node.name) mempty
                            Node.ModuleNode     -> addHandler (UINode.EnterNodeHandler $ enterNode $ Breadcrumb.Module   $ Text.unpack $ node ^. Node.name) mempty
                            _                   -> mempty

updateNode :: Node -> Command State ()
updateNode node = do
    let nodeId  = node ^. Node.nodeId
    maybeWidgetId <- inRegistry $ nodeIdToWidgetId nodeId
    zoom Global.graph $ modify (Graph.addNode node)
    forM_ maybeWidgetId $ \widgetId -> do
        updateNodeMeta nodeId $ node ^. Node.nodeMeta
        inRegistry $ displayPorts widgetId node
        updatePortAngles

        case node ^. Node.nodeType of
            Node.ExpressionNode expression -> do
                inRegistry $ UICmd.update_ widgetId $ Model.expression .~ expression
            _ -> return ()
        -- TODO: obsluzyc to ze moga zniknac polaczenia

onValueChanged :: Typeable a => (a -> WidgetId -> Command Global.State ()) -> HTMap
onValueChanged h = addHandler (ValueChangedHandler h) mempty

makePortControl :: WidgetId -> NodeId -> Port -> Command UIRegistry.State ()
makePortControl parent nodeId port = case port ^. Port.portId of
    OutPortId _ -> return ()
    InPortId inPort -> makeInPortControl parent nodeId inPort port

makeInPortControl :: WidgetId -> NodeId -> InPort -> Port -> Command UIRegistry.State ()
makeInPortControl parent nodeId inPort port = case port ^. Port.state of
    Port.NotConnected    -> do
        let group = Group.create & Group.style . Group.padding .~ Style.Padding 0.0 0.0 0.0 Style.setLabelOffsetX
        groupId <- UICmd.register parent group (Layout.horizontalLayoutHandler 0.0)
        let label  = Label.create Style.setLabelSize (Text.pack $ show inPort)
                   & Label.position . x .~ Style.setLabelOffsetX
            button = Button.create Style.setButtonSize "Set"
            handlers = addHandler (Button.ClickedHandler $ \_ -> do
                workspace <- use Global.workspace
                performIO $ BatchCmd.setDefaultValue workspace (InPortRef nodeId inPort) (DefaultValue.Constant $ DefaultValue.IntValue def)
                ) mempty

        UICmd.register_ groupId label def
        UICmd.register_ groupId button handlers
    Port.Connected       -> do
        let widget = Label.create (Style.portControlSize & x -~ Style.setLabelOffsetX) (Text.pack $ show inPort <> " (connected)")
                   & Label.position . x .~ Style.setLabelOffsetX
        void $ UICmd.register parent widget def
    Port.WithDefault def -> void $ case port ^. Port.valueType . ValueType.toEnum of
        ValueType.DiscreteNumber -> do
            let label = show inPort
                value = fromMaybe 0 $ def ^? DefaultValue._Constant . DefaultValue._IntValue
                widget = DiscreteNumber.create Style.portControlSize (Text.pack $ show inPort) value
                handlers = onValueChanged $ \val _ -> do
                    workspace <- use Global.workspace
                    performIO $ BatchCmd.setDefaultValue workspace (InPortRef nodeId inPort) (DefaultValue.Constant $ DefaultValue.IntValue val)
            UICmd.register parent widget handlers
        ValueType.ContinuousNumber -> do
            let label = show inPort
                value = fromMaybe 0.0 $ def ^? DefaultValue._Constant . DefaultValue._DoubleValue
                widget = ContinuousNumber.create Style.portControlSize (Text.pack $ show inPort) value
                handlers = onValueChanged $ \val _ -> do
                    workspace <- use Global.workspace
                    performIO $ BatchCmd.setDefaultValue workspace (InPortRef nodeId inPort) (DefaultValue.Constant $ DefaultValue.DoubleValue val)
            UICmd.register parent widget handlers
        ValueType.String -> do
            let label = show inPort
                value = fromMaybe "" $ def ^? DefaultValue._Constant . DefaultValue._StringValue
                widget = LabeledTextBox.create Style.portControlSize (Text.pack $ show inPort) (Text.pack $ value)
                handlers = onValueChanged $ \val _ -> do
                    workspace <- use Global.workspace
                    performIO $ BatchCmd.setDefaultValue workspace (InPortRef nodeId inPort) (DefaultValue.Constant $ DefaultValue.StringValue $ Text.unpack val)
            UICmd.register parent widget handlers
        ValueType.Bool -> do
            let label = show inPort
                value = fromMaybe True $ def ^? DefaultValue._Constant . DefaultValue._BoolValue
                widget = Toggle.create Style.portControlSize (Text.pack $ show inPort) value
                handlers = onValueChanged $ \val _ -> do
                    workspace <- use Global.workspace
                    performIO $ BatchCmd.setDefaultValue workspace (InPortRef nodeId inPort) (DefaultValue.Constant $ DefaultValue.BoolValue val)
            UICmd.register parent widget handlers
        ValueType.Other -> do
            let widget = Label.create Style.portControlSize (Text.pack $ show inPort <> " :: " <> (show $ port ^. Port.valueType) )
            UICmd.register parent widget mempty


nodeValueToText :: Value -> Text
nodeValueToText (IntValue    v) = Text.pack $ show v
nodeValueToText (DoubleValue v) = Text.pack $ show v
nodeValueToText (BoolValue   v) = Text.pack $ show v
nodeValueToText (StringValue v) = Text.pack v
nodeValueToText (IntList     v) = Text.pack $ "Vector [" <> (show $ length v) <> "]"
nodeValueToText (DoubleList  v) = Text.pack $ "Vector [" <> (show $ length v) <> "]"
nodeValueToText (BoolList    v) = Text.pack $ "Vector [" <> (show $ length v) <> "]"
nodeValueToText (StringList  v) = Text.pack $ "Vector [" <> (show $ length v) <> "]"

removeVisualization :: WidgetId -> Command UIRegistry.State ()
removeVisualization id = do
    groupId <- Node.valueGroupId id
    widgets <- UICmd.children groupId
    forM_ widgets UICmd.removeWidget

zipVector :: [Double] -> [Vector2 Double] -> [Vector2 Double]
zipVector (ax:xs) [] = zipVector xs [Vector2 0 ax]
zipVector (ax:xs) (acc:accs) = zipVector xs ((Vector2 (acc ^. x + 1.0) ax):acc:accs)
zipVector [] accs = accs

zipVectorInt :: [Int] -> [Vector2 Double] -> [Vector2 Double]
zipVectorInt (ax:xs) [] = zipVectorInt xs [Vector2 0 (fromIntegral ax)]
zipVectorInt (ax:xs) (acc:accs) = zipVectorInt xs ((Vector2 (acc ^. x + 1.0) (fromIntegral ax)):acc:accs)
zipVectorInt [] accs = accs

visualizeNodeValue :: WidgetId -> Value -> Command UIRegistry.State ()
visualizeNodeValue id (IntList     v) = do
    groupId <- Node.valueGroupId id

    let dataPoints = zipVectorInt v []
        widget = ScatterPlot.create Style.plotSize
               & ScatterPlot.dataPoints .~ dataPoints
    UICmd.register_ groupId widget def

visualizeNodeValue id (DoubleList     v) = do
    groupId <- Node.valueGroupId id

    let dataPoints = zipVector v []
        widget = ScatterPlot.create Style.plotSize
               & ScatterPlot.dataPoints .~ dataPoints
    UICmd.register_ groupId widget def

visualizeNodeValue _ _ = return ()



updateNodeValue :: NodeId -> Value -> Command State ()
updateNodeValue id val = inRegistry $ do
    widgetId <- nodeIdToWidgetId id
    forM_ widgetId $ \widgetId -> do
        UICmd.update_ widgetId $ Model.value .~ nodeValueToText val
        removeVisualization widgetId
        visualizeNodeValue widgetId val
