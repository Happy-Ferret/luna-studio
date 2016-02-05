---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.Bus.Data.Prefix where

import           Control.Arrow          (first)
import           Flowbox.Bus.Data.Topic (Topic)
import           Flowbox.Prelude



type Prefix = String


prefixify :: Prefix -> Topic -> Topic
prefixify prefix topic = if null prefix
    then topic
    else prefix ++ "." ++ topic


prefixifyTopics :: Prefix -> [(Topic, a)] -> [(Topic, a)]
prefixifyTopics prefix = map (first $ prefixify prefix)
