module Event.Event where

import Data.Monoid
import Data.Typeable
import Data.Dynamic
import Data.Default
import Control.Lens

import Object.Object ( Object )
import Object.Dynamic
import Utils.PrettyPrinter

import qualified Event.Keyboard      as Keyboard
import qualified Event.Mouse         as Mouse
import qualified Event.Window        as Window
import qualified Event.NodeSearcher  as NodeSearcher
import qualified Event.WithObjects   as WithObjects


data Event obj = Init
               | Window       Window.Event
               | Keyboard     Keyboard.Event
               | Mouse        Mouse.Event
               | NodeSearcher NodeSearcher.Event


makeLenses ''Event

instance Default (Event obj) where
    def = Init

instance Typeable obj => UnpackDynamic (Event Dynamic) (Event obj) where
    unpackDynamic Init              = Init
    unpackDynamic (Window       ev) = Window ev
    unpackDynamic (Keyboard     ev) = Keyboard ev
    unpackDynamic (Mouse        ev) = Mouse ev
    unpackDynamic (NodeSearcher ev) = NodeSearcher ev

instance PrettyPrinter obj => PrettyPrinter (Event obj) where
    display Init              = "InitEv"
    display (Window       ev) = "WinEv(" <> display ev <> ")"
    display (Keyboard     ev) = "KeyEv(" <> display ev <> ")"
    display (Mouse        ev) = "MouEv(" <> display ev <> ")"
    display (NodeSearcher ev) = "NoSEv(" <> display ev <> ")"
