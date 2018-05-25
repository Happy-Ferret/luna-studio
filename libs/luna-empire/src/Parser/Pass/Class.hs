{-# LANGUAGE UndecidableInstances #-}

module Parser.Pass.Class where

import           Prologue hiding (String, Symbol, Tok, Type)
import qualified Prologue as P

import qualified Data.Graph.Data.Graph.Class          as Graph
import qualified Data.List                            as List
import qualified Data.Set                             as Set
import qualified Luna.IR                              as IR
import qualified Luna.IR                              as IR
import qualified Luna.Pass                            as Pass
import qualified Luna.Pass.Attr                       as Attr
import qualified Luna.Syntax.Text.Lexer               as Lexer
import qualified Parser.State.Marker as Marker
import qualified OCI.Pass.Definition.Declaration      as Pass
import qualified Text.Megaparsec                      as Parser
import qualified Text.Megaparsec.Error                as Error
import qualified Text.Megaparsec.Error                as Error


import Control.Monad.State.Layered           (StatesT)
import Data.Set                              (Set)
import Data.Text.Position                    (Delta)
import Luna.Pass                             (Pass)
import Parser.Data.CodeSpan (CodeSpan)
import Parser.Data.Invalid  (Invalids)
import Parser.Data.Result   (Result)
import Luna.Syntax.Text.Source               (Source)

import Empire.Pass.PatternTransformation as PT


-------------------------
-- === Parser pass === --
-------------------------

-- === Definition === --

data Parser
type instance Pass.Spec Parser t = ParserSpec t
type family   ParserSpec  t where
    ParserSpec Pass.Stage            = PT.EmpireStage
    ParserSpec (Pass.In  Pass.Attrs) = Pass.List '[Source, Result, Invalids]
    -- ParserSpec (Pass.In  IR.Terms)   = CodeSpan
                                    -- ': Pass.BasicPassSpec (Pass.In IR.Terms)
    ParserSpec (Pass.Out t)          = ParserSpec (Pass.In t)
    ParserSpec t                     = Pass.BasicPassSpec t

-- Pass.cache_phase1 ''Parser
-- Pass.cache_phase2 ''Parser



-----------------
-- === IRB === --
-----------------

-- === Definition === --

-- | IRB:  IR Builder
--   IRBS: IR Builder Spanned
--   Both IRB and IRBS are Luna IR building monads, however the construction
--   of IRBS is handled by functions which guarantee that IRB has all code
--   spanning information encoded

type    IRB    = StatesT '[Marker.TermOrphanList, Marker.TermMap] (Pass Parser)
newtype IRBS a = IRBS (IRB a)
    deriving (Functor, Applicative, Monad)
makeLenses ''IRBS


-- === Utils === --

fromIRBS :: IRBS a -> IRB a
fromIRBS (IRBS a) = a ; {-# INLINE fromIRBS #-}

liftIRBS1 :: (t1             -> IRB out) -> IRBS t1                       -> IRB out
liftIRBS2 :: (t1 -> t2       -> IRB out) -> IRBS t1 -> IRBS t2            -> IRB out
liftIRBS3 :: (t1 -> t2 -> t3 -> IRB out) -> IRBS t1 -> IRBS t2 -> IRBS t3 -> IRB out
liftIRBS1 f t1       = bind  f (fromIRBS t1)                             ; {-# INLINE liftIRBS1 #-}
liftIRBS2 f t1 t2    = bind2 f (fromIRBS t1) (fromIRBS t2)               ; {-# INLINE liftIRBS2 #-}
liftIRBS3 f t1 t2 t3 = bind3 f (fromIRBS t1) (fromIRBS t2) (fromIRBS t3) ; {-# INLINE liftIRBS3 #-}


-- === Instances === --

instance Show (IRBS a) where
    show _ = "IRBS"








