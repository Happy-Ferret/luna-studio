module LunaStudio.API.Graph.CollapseToFunction where

import           Data.Binary                   (Binary)
import qualified LunaStudio.API.Graph.Request  as G
import           LunaStudio.API.Graph.Result   (Result)
import qualified LunaStudio.API.Request        as R
import qualified LunaStudio.API.Response       as Response
import qualified LunaStudio.API.Topic          as T
import           LunaStudio.Data.Connection    (Connection)
import           LunaStudio.Data.GraphLocation (GraphLocation)
import           LunaStudio.Data.Node          (ExpressionNode)
import           LunaStudio.Data.NodeLoc       (NodeLoc)
import           Prologue                      hiding (TypeRep)


data Request = Request { _location :: GraphLocation
                       , _nodeLocs :: [NodeLoc]
                       } deriving (Eq, Generic, Show)

data Inverse = Inverse { _nodes       :: [ExpressionNode]
                       , _connections :: [Connection]
                       } deriving (Eq, Generic, Show)

makeLenses ''Request
makeLenses ''Inverse
instance Binary Request
instance NFData Request
instance Binary Inverse
instance NFData Inverse
instance G.GraphRequest Request where location = location

-- TODO[MK]: handle inverses
type Response = Response.Response Request () Result
instance Response.ResponseResult Request () Result

topicPrefix :: T.Topic
topicPrefix = "empire.graph.node.collapsetofunction"
instance T.MessageTopic (R.Request Request) where topic _ = topicPrefix <> T.request
instance T.MessageTopic Response            where topic _ = topicPrefix <> T.response
