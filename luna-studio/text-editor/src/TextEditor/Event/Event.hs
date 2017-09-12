{-# LANGUAGE DeriveAnyClass #-}
module TextEditor.Event.Event where

import           Data.Aeson                  (ToJSON)

import           Common.Analytics            (IsTrackedEvent (..), (<.$>))
import           Common.Prelude
import           TextEditor.Event.Batch      (BatchEvent)
import qualified TextEditor.Event.Connection as Connection
import           TextEditor.Event.Internal   (InternalEvent)
import           TextEditor.Event.Text       (TextEvent)


data Event = Init
           | Atom                        InternalEvent
           | Batch                          BatchEvent
           | Connection               Connection.Event
           | Text                            TextEvent
           deriving (Generic, Show, NFData)


instance ToJSON Event

name :: Getter Event String
name = to $ head . words . show


instance IsTrackedEvent Event where
    eventName event = ("TextEditor.Event." <> (event ^. name)) <.$> case event of
        Init -> Just ""
        Atom a       -> eventName a
        Batch b      -> eventName b
        Connection c -> eventName c
        Text t       -> eventName t
