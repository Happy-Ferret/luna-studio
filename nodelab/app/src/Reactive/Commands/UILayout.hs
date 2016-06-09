module Reactive.Commands.UILayout
    ( relayout
    , relayoutTextEditor
    ) where

import           Utils.PreludePlus
import           Utils.Vector                 (Vector2 (..), x, y)

import qualified JS.TextEditor                as UI
import qualified Object.Widget.Button         as Button
import           Reactive.Commands.Command    (Command, performIO)
import qualified Reactive.Commands.UIRegistry as UICmd
import qualified Reactive.State.Camera        as Camera
import           Reactive.State.Global        (State, inRegistry)
import qualified Reactive.State.Global        as Global
import qualified Reactive.State.UIElements    as UIElements
import qualified Style.Layout                 as Style


relayout = resizeSidebar >> resizeTextEditorToggle

resizeSidebar :: Command State ()
resizeSidebar = do
    screenSize <- use $ Global.camera . Camera.camera . Camera.screenSize
    sidebarId <- use $ Global.uiElements . UIElements.sidebar
    inRegistry $ UICmd.resize sidebarId (Vector2 Style.sidebarWidth $ fromIntegral $ screenSize ^. y)

    bcId <- use $ Global.uiElements . UIElements.breadcrumbs
    inRegistry $ UICmd.resize bcId (Vector2 (fromIntegral $ screenSize ^. x) Style.breadcrumbsHeight)

resizeTextEditorToggle :: Command State ()
resizeTextEditorToggle = do
    screenSize <- use $ Global.camera     . Camera.camera . Camera.screenSize
    toggleId   <- use $ Global.uiElements . UIElements.textEditorToggle
    inRegistry $ do
        let width = Style.textEditorToggle ^. Button.size . x
        UICmd.moveX  toggleId $ (fromIntegral $ screenSize ^. x) - width
        UICmd.resize toggleId $ Vector2 width (fromIntegral $ screenSize ^. y)


relayoutTextEditor :: Vector2 Int -> Command Global.State Int
relayoutTextEditor screenSize = do
    visible    <- use $ Global.uiElements . UIElements.textEditorVisible
    performIO $ UI.setVisible visible
    let width = (floor $ 0.3 * (fromIntegral $ screenSize ^. x))
    performIO $ UI.setWidth width

    return $ if visible then width else 0