{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}
module NodeEditor.React.View.Sidebar
    ( sidebar_
    , focusPortLabel
    ) where

import           Common.Prelude
import qualified Data.Aeson                              as Aeson
import qualified JS.Config                               as Config
import           JS.Scene                                (inputSidebarId, outputSidebarId)
import qualified JS.UI                                   as UI
import           LunaStudio.Data.PortRef                 (AnyPortRef (OutPortRef'), OutPortRef (OutPortRef), toAnyPortRef)
import qualified LunaStudio.Data.PortRef                 as PortRef
import           LunaStudio.Data.Position                (y)
import qualified NodeEditor.Event.UI                     as UI
import qualified NodeEditor.React.Event.Sidebar          as Sidebar
import           NodeEditor.React.Model.App              (App)
import           NodeEditor.React.Model.Constants        (lineHeight)
import           NodeEditor.React.Model.Node.SidebarNode (NodeLoc, SidebarMode (AddRemove, MoveConnect), SidebarNode, countProjectionPorts,
                                                          isInputSidebar)
import qualified NodeEditor.React.Model.Node.SidebarNode as SidebarNode
import           NodeEditor.React.Model.Port             (AnyPort, OutPortIndex (Projection), getPortNumber, getPositionInSidebar,
                                                          isHighlighted, isInMovedMode, isInNameEditMode, isInPort, isOutPort)
import qualified NodeEditor.React.Model.Port             as Port
import           NodeEditor.React.Model.Searcher         (Searcher)
import qualified NodeEditor.React.Model.Searcher         as Searcher
import           NodeEditor.React.Store                  (Ref, dispatch)
import           NodeEditor.React.View.Port              (handleClick, handleMouseDown, handleMouseUp, jsShow2)
import           NodeEditor.React.View.Searcher          (searcher_)
import           NodeEditor.React.View.Style             (plainPath_, plainRect_)
import qualified NodeEditor.React.View.Style             as Style
import           React.Flux                              as React hiding (view)

name :: SidebarNode node => node -> JSString
name node = "sidebarPorts" <> if isInputSidebar node then "Inputs" else "Outputs"

portViewBox :: JSString
portViewBox = "-16 -16 32 32"

portHandlers :: Ref App -> SidebarMode -> Bool -> Bool -> AnyPortRef -> [PropertyOrHandler [SomeStoreAction]]
portHandlers ref AddRemove _ isOnly portRef =
    [ onMouseDown $ \e _ -> [stopPropagation e] ] <>
    if isOnly then [] else
    [ onClick      $ \e _ -> stopPropagation e : dispatch ref (UI.SidebarEvent $ Sidebar.RemovePort portRef)
    , onMouseLeave $ \_ _ -> dispatch ref (UI.SidebarEvent . Sidebar.UnfreezeSidebar $ portRef ^. PortRef.nodeLoc)
    ]

portHandlers ref MoveConnect False _ portRef =
    [ onMouseDown $ \e _ -> [stopPropagation e]
    , onClick     $ handleClick     ref portRef
    , onMouseDown $ handleMouseDown ref portRef
    , onMouseUp   $ handleMouseUp   ref portRef
    ]
portHandlers _ _ _ _ _ = []

sidebar_ :: SidebarNode node => Ref App -> Maybe Searcher -> node ->  ReactElementM ViewEventHandler ()
sidebar_ ref maySearcher node = React.viewWithSKey sidebar (name node) (ref, maySearcher, node) mempty

sidebar :: SidebarNode node => ReactView (Ref App, Maybe Searcher, node)
sidebar = React.defineView "sidebar" $ \(ref, maySearcher, node) -> do
    let ports         = SidebarNode.portsList node
        nodeLoc       = node ^. SidebarNode.nodeLoc
        mode          = node ^. SidebarNode.mode
        isPortDragged = any isInMovedMode ports
        classes       = [ "sidebar", if isInputSidebar node then "sidebar--i" else "sidebar--o" ]
                      <> if mode == AddRemove then ["sidebar--editmode"] else []
                      <> if isPortDragged then ["sidebar--dragmode"] else []
        addButtonHandlers = case mode of
                                AddRemove   -> [ onMouseDown $ \e _ -> [stopPropagation e]
                                               , onClick     $ \e _ -> stopPropagation e : dispatch ref (UI.SidebarEvent $ Sidebar.AddPort portRef)
                                               ]
                                MoveConnect -> portHandlers ref mode False False portRef
                            where portRef = OutPortRef' (OutPortRef nodeLoc [Projection (countProjectionPorts node)])
    div_
        [ "className"   $= Style.prefixFromList classes
        , onDoubleClick $ \e _ -> [stopPropagation e]
        , onMouseDown   $ \e _ -> [stopPropagation e]
        , onMouseMove   $ \e m -> stopPropagation e : (dispatch ref $ UI.SidebarEvent $ Sidebar.MouseMove m nodeLoc)
        ] $
        div_
            [ "key" $= "activeArea"
            , "className" $= Style.prefixFromList [ "sidebar__active-area", "noselect" ]
            ] $
            div_
                [ "key"       $= "SidebarPortsBody"
                , "id"        $= if isInputSidebar node then inputSidebarId else outputSidebarId
                , "className" $= Style.prefixFromList [ "sidebar__body", "noselect" ]
                ] $ do
                forM_ ports $ \p -> if isInMovedMode p
                    then sidebarPlaceholderForPort_ >> sidebarDraggedPort_ ref p
                    else sidebarPort_ ref nodeLoc p mode isPortDragged (countProjectionPorts node == 1) (filterOutSearcherIfNotRelated (toAnyPortRef nodeLoc $ p ^. Port.portId) maySearcher)
                when (isInputSidebar node) $ do

                    svg_ (
                        [ "className" $= Style.prefixFromList [ "sidebar__port__svg", "sidebar__port__svg--addbutton" ]
                        , "viewBox"   $= portViewBox
                        , "key"       $= (name node <> "AddButton")
                        ] <> addButtonHandlers ) $ do
                        circle_
                            [ "className" $= Style.prefix "port__shape"
                            , "key"       $= jsShow "addButtonShape"
                            , "r"         $= jsShow2 3
                            ] mempty
                        g_ [ "className" $= Style.prefix "port__plus" ] $ do
                              plainRect_ "key1" 0 0 0 0
                              plainRect_ "key2" 0 0 0 0
                        circle_
                            [ "className" $= Style.prefix "port__select"
                            , "key"       $= jsShow "addButtonSelect"
                            , "r"         $= jsShow2 16
                            ] mempty

                    svg_
                        [ "className" $= Style.prefix "edit-icon"
                        , "viewBox"   $= portViewBox
                        , onClick $ \e _ -> stopPropagation e : dispatch ref (UI.SidebarEvent $ Sidebar.ToggleInputMode nodeLoc)
                        , "key"       $= (name node <> "editIcon")
                        ] $ do
                        circle_
                            [ "className" $= Style.prefix "edit-icon__shape01"
                            , "key"       $= jsShow "editIconShape"
                            , "r"         $= jsShow2 3
                            ] mempty
                        g_ [ "className" $= Style.prefix "edit-icon__shape02" ] $ do
                              plainPath_ "" ""
                              plainRect_ "key1" 0 0 0 0
                              plainRect_ "key2" 0 0 0 0
                        circle_
                            [ "className" $= Style.prefix "edit-icon__select"
                            , "key"       $= jsShow "editIconSelect"
                            , "r"         $= jsShow2 16
                            ] mempty


sidebarPortName_ :: Ref App -> AnyPortRef -> Text -> Maybe Searcher -> ReactElementM ViewEventHandler ()
sidebarPortName_ ref portRef portName mayS = div_ ([ "className" $= Style.prefixFromList [ "sidebar__port__name", "noselect"] ] <> handlers) nameElement where
    regularName             = elemString $ convert portName
    (handlers, nameElement) = case portRef of
        OutPortRef' outPortRef -> do
            let outPortRefRegularHandler = [ onDoubleClick $ \e _ -> stopPropagation e : dispatch ref (UI.SidebarEvent $ Sidebar.EditPortName outPortRef) ]
                regularHandlersAndElem   = (outPortRefRegularHandler, regularName)
            flip (maybe regularHandlersAndElem) mayS $ \s -> case s ^. Searcher.mode of
                Searcher.PortName sPortRef _ -> if sPortRef == outPortRef then ([], searcher_ ref s) else regularHandlersAndElem
                _                            -> regularHandlersAndElem
        _ -> ([], regularName)

sidebarPort_ :: Ref App -> NodeLoc -> AnyPort -> SidebarMode -> Bool -> Bool -> Maybe Searcher -> ReactElementM ViewEventHandler ()
sidebarPort_ ref nl p mode isPortDragged isOnly maySearcher = do
    let portId    = p ^. Port.portId
        portRef   = toAnyPortRef nl portId
        color     = convert $ p ^. Port.color
        num       = getPortNumber portId
        highlight = if isHighlighted p || isInNameEditMode p then [ "hover" ] else []
        classes   = if isInPort portId then [ "port", "sidebar__port", "sidebar__port--o", "sidebar__port--o--" <> show (num + 1) ] <> highlight
                                       else [ "port", "sidebar__port", "sidebar__port--i", "sidebar__port--i--" <> show (num + 1) ] <> highlight
    div_
        [ "key"       $= ( jsShow portId <> "-port-" <> jsShow num )
        , "className" $= Style.prefixFromList classes
        ] $ do
        when (isOutPort portId) $ addButton_ ref portRef
        svg_
            [ "className" $= Style.prefix "sidebar__port__svg"
            , "viewBox"   $= portViewBox
            ] $ do
            circle_
                [ "className" $= Style.prefix "port__shape"
                , "key"       $= (jsShow portId <> jsShow num <> "a")
                , "fill"      $= color
                , "r"         $= jsShow2 3
                ] mempty
            when (not isOnly) $ g_ [ "className" $= Style.prefix "port__plus" ] $ do
                  plainRect_ "key1" 2 8 (-1) (-4)
                  plainRect_ "key2" 8 2 (-4) (-1)
            circle_ (
                [ "className" $= Style.prefix "port__select"
                , "key"       $= (jsShow portId <> jsShow num <> "b")
                , "r"         $= jsShow2 16
                ] <> portHandlers ref mode isPortDragged isOnly portRef ) mempty
        sidebarPortName_ ref portRef (p ^. Port.name) maySearcher

addButton_ :: Ref App -> AnyPortRef -> ReactElementM ViewEventHandler ()
addButton_ ref portRef = do
    let classes = ["sidebar__port__svg", "sidebar__port__svg--inbetween"]
    svg_
        [ "className"  $= Style.prefixFromList classes
        , onMouseDown  $ \e _ -> [stopPropagation e]
        , onClick      $ \e _ -> stopPropagation e : dispatch ref (UI.SidebarEvent $ Sidebar.AddPort portRef)
        , onMouseLeave $ \_ _ -> dispatch ref (UI.SidebarEvent . Sidebar.UnfreezeSidebar $ portRef ^. PortRef.nodeLoc)
        ] $
        g_ [ "className" $= Style.prefix "port-add-inbetween" ] $ do
            g_ [ "className" $= Style.prefix "port-add-inbetween__shape" ] $ do
                plainPath_ (Style.prefix "port-add-inbetween__droplet") "M10.0749836,12.9509892 C11.4541267,14.1514559 13.0835452,14.9902759 15.0097241,14.9902759 C18.8703469,14.9902759 22,11.8606228 22,8 C22,4.13937722 18.8703469,1.0097241 15.0097241,1.0097241 C13.0977164,1.0097241 11.4518168,1.82232527 10.1029674,3.02127407 C5.44945277,7.13675725 4.06697429,7.99999996 1.05578798,7.99999996 C4.06697429,7.99999996 5.38818292,8.87139207 10.0749836,12.9509892 Z"
                g_ [ "className" $= Style.prefix "port-add-inbetween__plus" ] $ do
                    plainRect_ "key1" 2 8 (-1) (-4)
                    plainRect_ "key2" 8 2 (-4) (-1)
            plainPath_ (Style.prefix "port-add-inbetween__selectable") "M 20 0 A 10 10 0 0 1 20 16 L 10 16 A 10 10 0 0 1 10 0 Z"

sidebarPlaceholderForPort_ :: ReactElementM ViewEventHandler ()
sidebarPlaceholderForPort_ = div_
    [ "key"       $= "port-placeholder"
    , "className" $= Style.prefixFromList [ "port", "sidebar__port", "sidebar__port--i", "noselect" ]
    ] mempty

sidebarDraggedPort_ :: Ref App -> AnyPort -> ReactElementM ViewEventHandler ()
sidebarDraggedPort_ _ref p = withJust (getPositionInSidebar p) $ \pos ->
    div_
        [ "className" $= Style.prefixFromList [ "port", "sidebar__port", "sidebar__port--dragged", "hover" ]
        , "style"     @= Aeson.object [ "transform"  Aeson..= ("translate(0px, " <> show (pos ^. y) <> "px)") ]
        ] $ do
        div_ [ "className" $= Style.prefix "sidebar__port__name" ] $ elemString . convert $ p ^. Port.name
        svg_
            [ "className" $= Style.prefix "sidebar__port__svg" ] $
            circle_
                [ "className" $= Style.prefix "port__shape"
                , "r"         $= jsShow2 3
                ] mempty

portLabelId :: JSString
portLabelId = Config.prefix "focus-portLabel"

focusPortLabel :: IO ()
focusPortLabel = UI.focus portLabelId

filterOutSearcherIfNotRelated :: AnyPortRef -> Maybe Searcher -> Maybe Searcher
filterOutSearcherIfNotRelated (OutPortRef' portRef) (Just s) = case s ^. Searcher.mode of
    Searcher.PortName sPortRef _ -> if portRef == sPortRef then Just s else Nothing
    _                            -> Nothing
filterOutSearcherIfNotRelated _ _ = Nothing
