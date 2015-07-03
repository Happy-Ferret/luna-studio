module Event.WithObjects where

import Data.Monoid
import Data.Typeable
import Data.Dynamic
import Data.Default
import Control.Lens

import Object.Object ( Object )
import Object.Dynamic
import Utils.PrettyPrinter


data WithObjects evnt obj = WithObjects { _event   :: evnt
                                        , _objects :: [Object obj]
                                        } deriving (Eq, Show)

makeLenses ''WithObjects

instance Default a => Default (WithObjects a obj) where
    def = WithObjects def def

instance Typeable obj => UnpackDynamic (WithObjects evnt Dynamic) (WithObjects evnt obj) where
    unpackDynamic = objects %~ unpackDynamic

instance (PrettyPrinter evnt, PrettyPrinter obj) => PrettyPrinter (WithObjects evnt obj) where
    display (WithObjects ev objs) = "wo( " <> display ev <> " " <> display objs <> " )"
