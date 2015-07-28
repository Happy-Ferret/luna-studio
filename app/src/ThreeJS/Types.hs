{-# LANGUAGE OverloadedStrings #-}

module ThreeJS.Types where

import           Utils.PreludePlus
import qualified GHCJS.Prim.Internal.Build as Build

import           GHCJS.Foreign
import           GHCJS.Types      ( JSRef )
import           GHCJS.DOM.EventTargetClosures (EventName, unsafeEventName)
import           Data.JSString.Text ( lazyTextFromJSString, lazyTextToJSString )
import           Data.JSString ( JSString )
import qualified Data.JSString as JSString

import           JavaScript.Array ( JSArray )
import qualified JavaScript.Array as JSArray

import qualified Data.Text.Lazy as Text
import           Data.Text.Lazy (Text)
import qualified JavaScript.Object as JSObject

import Unsafe.Coerce
import System.IO.Unsafe
import Debug.Trace

import GHCJS.Prim
import ThreeJS.Converters
import ThreeJS.Registry

class Container a where
    add    :: (Object b) => a -> b -> IO ()
    remove :: (Object b) => a -> b -> IO ()

data MeshJS
type Mesh  = JSRef MeshJS
data Group = Group {unGroup :: Mesh}
data Scene = Scene (JSRef Scene)



class Object a where mesh :: a -> IO Mesh

instance Object Mesh  where mesh a = return a
instance Object Group where mesh (Group a) = return a

data JSVector2
data JSVector3
data JSVector4

foreign import javascript unsafe "new THREE.Vector2($1, $2)"
    buildVector2 :: Double -> Double -> IO (JSRef JSVector2)
foreign import javascript unsafe "new THREE.Vector2($1, $2, $3)"
    buildVector3 :: Double -> Double -> Double -> IO (JSRef JSVector3)
foreign import javascript unsafe "new THREE.Vector4($1, $2, $3, $4)"
    buildVector4 :: Double -> Double -> Double -> Double -> IO (JSRef JSVector4)

foreign import javascript unsafe "$1.x = $2" setX :: JSRef a -> Double -> IO ()
foreign import javascript unsafe "$1.y = $2" setY :: JSRef a -> Double -> IO ()
foreign import javascript unsafe "$1.z = $2" setZ :: JSRef a -> Double -> IO ()
foreign import javascript unsafe "$1.a = $2" setA :: JSRef a -> Double -> IO ()


class Geometry a
class IsMaterial a where material :: a -> Material


data MaterialJS
type Material = JSRef MaterialJS
--
-- data Uniform
-- -- type Attribute = Uniform
-- data UniformMap
-- -- type AttributeMap = UniformMap
--
-- foreign import javascript unsafe "{type: $1, value: $2}"
--   buildUniformJS :: JSString -> JSRef a -> IO (JSRef Uniform)
--
-- class ToUniform a where
--     toUniform :: a -> IO (JSRef Uniform)
--
-- instance ToUniform Int               where toUniform a = buildUniformJS (lazyTextToJSString "i" ) (toJSInt a)
-- instance ToUniform Double            where toUniform a = buildUniformJS (lazyTextToJSString "f" ) (toJSDouble a)
-- instance ToUniform (JSRef JSVector2) where toUniform a = buildUniformJS (lazyTextToJSString "v2") a
-- instance ToUniform (JSRef JSVector3) where toUniform a = buildUniformJS (lazyTextToJSString "v2") a
-- instance ToUniform (JSRef JSVector4) where toUniform a = buildUniformJS (lazyTextToJSString "v4") a
--
--
-- foreign import javascript unsafe "$1.value = $2" setValue :: JSRef Uniform -> JSRef a -> IO()
--
--
--
-- foreign import javascript unsafe "$r = {}"
--   js_empty :: IO (JSRef a)
-- foreign import javascript unsafe "$1[$2] = $3" js_setProp :: JSRef a -> JSString -> JSRef c -> IO ()
--
--
-- toUniformMap :: [(Text, JSRef Uniform)] -> IO (JSRef UniformMap)
-- toUniformMap items = do
--     list <- js_empty
--     mapM_ (\(k, v) -> js_setProp list (lazyTextToJSString k) v) items
--     return list
--
-- -- toAttributeMap :: [(Text, JSRef Attribute)] -> IO (JSRef AttributeMap)
-- toAttributeMap = toUniformMap



newtype AttributeMap = AttributeMap { unAttributeMap :: JSObject.Object }
newtype Attribute = Attribute { unAttribute :: JSObject.Object }

buildAttributeMap :: IO (AttributeMap)
buildAttributeMap = JSObject.create >>= return . AttributeMap

setValue :: Attribute -> JSRef a -> IO ()
setValue o v = JSObject.setProp (JSString.pack "value") v (unAttribute o)

class ToAttribute a where
    toAttribute :: a -> IO Attribute


buildAttribute :: Text -> JSRef a -> IO (Attribute)
buildAttribute t v = do
    o <- JSObject.create

    let x = JSString.getJSRef $ lazyTextToJSString t
    JSObject.setProp (JSString.pack "type") x o
    JSObject.setProp (JSString.pack "value") v o
    return $ Attribute o

instance ToAttribute Int               where toAttribute a = buildAttribute "i"  (toJSInt a)
instance ToAttribute Double            where toAttribute a = buildAttribute "f"  (toJSDouble a)
instance ToAttribute (JSRef JSVector2) where toAttribute a = buildAttribute "v2" a
instance ToAttribute (JSRef JSVector3) where toAttribute a = buildAttribute "v2" a
instance ToAttribute (JSRef JSVector4) where toAttribute a = buildAttribute "v4" a

setAttribute :: AttributeMap -> Text -> Attribute -> IO ()
setAttribute m a v = JSObject.setProp (lazyTextToJSString a) (JSObject.getJSRef $ unAttribute v) (unAttributeMap m)