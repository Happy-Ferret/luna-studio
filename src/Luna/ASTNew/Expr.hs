---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds           #-}
{-# LANGUAGE DeriveGeneric             #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE TemplateHaskell           #-}

{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE FunctionalDependencies    #-}

module Luna.ASTNew.Expr where

import Flowbox.Prelude

import Control.Applicative
import GHC.Generics        (Generic)

import           Flowbox.Generics.Deriving.QShow

import           Luna.ASTNew.Name (VName, TName, CName, TVName, NameBase)
import qualified Luna.ASTNew.Name as Name

import           Luna.ASTNew.Decl       (Decl)
import           Luna.ASTNew.Lit        (LLit)
import           Luna.ASTNew.Pat        (Pat, LPat)
import           Luna.ASTNew.Type       (Type, LType)
import           Luna.ASTNew.Native     (Native)
import           Luna.ASTNew.Name.Multi (MultiName)
import           Luna.ASTNew.Arg        (Arg)
import           Luna.ASTNew.Label      (Label)


type Selector = [VName]

data App e = Seq   [Named VName e]
           | Infix e e
           deriving (Show, Eq, Generic, Read)


data Named n v = Named   n v
               | Unnamed v  
               deriving (Show, Eq, Generic, Read)

type LExpr   a v = Label a (Expr a v)
type ExprApp a v = App (LExpr a v)
type ExprArg a v = Label a (Arg a (Expr a v))
type SubDecl a v = Label a (Decl a (LExpr a v))



data Expr a v
    = Lambda      { _inputs  :: [ExprArg a v] , _output   :: LType a      , _body   :: [LExpr a v] }
    | RecUpdt     { _src     :: LExpr a v     , _selector :: Selector     , _expr   :: LExpr a v   }
    | App         { _src     :: LExpr a v     , _args     :: ExprApp a v                           }
    | Case        { _expr    :: LExpr a v     , _match    :: [LMatch a v]                          }
    | Typed       { _cls     :: LType a       , _expr     :: LExpr a v                             }
    | Assignment  { _dst     :: LPat  a       , _src      :: LExpr a v                             }
    | Accessor    { _acc     :: NameBase      , _src      :: LExpr a v                             }
    | Ref         { _ref     :: LExpr a v                                                          }
    | List        { _elems   :: LList a (LExpr a v)                                                }
    | Tuple       { _items   :: [LExpr a v]                                                        }
    | Grouped     { _expr    :: LExpr a v                                                          }
    | Cons        { _cname   :: CName                                                              }
    | Decl        { _decl    :: SubDecl a v                                                        }
    | Lit         { _lit     :: LLit a                                                             }
    | Native      { _native  :: Native (LExpr a v)                                                 }
    | Var         { _ident   :: v                                                                  }
    | Wildcard
    deriving (Show, Eq, Generic, Read)



data Match  a v = Match { _matchPat :: LPat a, _matchBody :: [LExpr a v] } deriving (Show, Eq, Generic, Read)
type LMatch a v = Label a (Match a v)


data List e = SeqList [e]
            | RangeList (Sequence e)
            deriving (Show, Eq, Generic, Read)

type LList a e = Label a (List e)

data Sequence a = Linear    a   (Maybe a)
                | Geometric a a (Maybe a)
                deriving (Show, Eq, Generic, Read)

