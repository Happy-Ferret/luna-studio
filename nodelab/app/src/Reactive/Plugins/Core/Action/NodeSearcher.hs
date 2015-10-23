{-# LANGUAGE OverloadedStrings #-}

module Reactive.Plugins.Core.Action.NodeSearcher where

import           Utils.PreludePlus
import           Utils.Vector hiding (shift)

import           GHCJS.Foreign

import           JS.Bindings
import qualified JS.NodeSearcher as UI

import           Object.Object
import qualified Object.Node    as Node
import           Event.Keyboard hiding      ( Event )
import qualified Event.Keyboard as Keyboard
import           Event.NodeSearcher hiding  ( Event )
import qualified Event.NodeSearcher as NodeSearcher
import           Event.Event
import           Reactive.Plugins.Core.Action
import           Reactive.State.NodeSearcher
import qualified Reactive.State.Global          as Global
import qualified Reactive.State.Selection       as Selection
import qualified Reactive.State.Graph           as Graph
import qualified Reactive.Plugins.Core.Action.NodeSearcher.Mock     as Mock

import qualified Data.Text.Lazy as Text
import           Data.Text.Lazy (Text)


data QueryType = Search | Tree deriving (Eq, Show)

data Action = Query      { _tpe        :: QueryType
                         , _expression :: Text
                         }
            | CreateNode { _expression :: Text }
            | OpenToCreate
            | OpenToEdit
            deriving (Eq, Show)


makeLenses ''Action

instance PrettyPrinter Action where
    display (Query Search expr) = "ns(query ["     ++ (Text.unpack expr) ++ "])"
    display (Query Tree   expr) = "ns(treequery [" ++ (Text.unpack expr) ++ "])"
    display (CreateNode   expr) = "ns(create ["    ++ (Text.unpack expr) ++ "])"
    display OpenToCreate        = "ns(openCreate)"
    display OpenToEdit          = "ns(openEdit)"


toAction :: Event Node.Node -> Maybe Action
toAction (NodeSearcher (NodeSearcher.Event tpe expr _))   = case tpe of
    "query"  -> Just $ Query Search expr
    "tree"   -> Just $ Query Tree   expr
    _        -> Nothing

toAction (Keyboard (Keyboard.Event Keyboard.Down char mods)) = case char of
    '\t'   -> Just $ if mods ^. shift then OpenToEdit else OpenToCreate
    _      -> Nothing

toAction _ = Nothing

instance ActionStateUpdater Action where
    execSt newAction oldState = ActionUI newAction oldState

instance ActionUIUpdater Action where
    updateUI (WithState action state) = case action of
        (Query Search expr)      -> UI.displayQueryResults $ Mock.getItemsSearch expr
        (Query Tree expr)        -> UI.displayTreeResults  $ Mock.getItemsTree   expr
        OpenToCreate             -> UI.initNodeSearcher ""   0      (state ^. Global.mousePos)
        OpenToEdit               -> case nodeId of
                     Just nodeId -> UI.initNodeSearcher expr nodeId (state ^. Global.mousePos)
                     Nothing     -> return ()
                     where
                        expr    = maybe "" (^. Node.expression) node
                        node    = Graph.getNode (state ^. Global.graph) <$> nodeId
                        nodeId  = state ^? Global.selection . Selection.nodeIds . ix 0




