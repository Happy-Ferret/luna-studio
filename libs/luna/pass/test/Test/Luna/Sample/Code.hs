---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE QuasiQuotes #-}

module Test.Luna.Sample.Code where

import Text.RawString.QQ

import Flowbox.Prelude
import Test.Luna.Pass.Transform.Graph.Common (named)
--import           Luna.Syntax.Control.Crumb             (Breadcrumbs)
--import qualified Luna.Syntax.Control.Crumb             as Crumb
--import qualified Luna.DEP.AST.Name                         as Name



type Name = String
type Code = String


sampleCodes :: [(Name, Code)]
sampleCodes = [named "empty" [r|
def main
|], named "simple return" [r|
def main:
    1
|], named "simple infix" [r|
def Int.+ a

def main:
    1 + 2
|], named "simple assignment 1" [r|
def main:
    x = 0
|], named "simple assignment 2" [r|
def print

def main:
    x = 0
    y = x
    print y
|], named "simple assignment 3" [r|
def main:
    x = 0
    (y, _) = x
|], named "simple assignment 4" [r|
def main:
    x = 0
    y = 1
    (z, v) = (x, y)
|], {-named "assignment with patterns" [r|
def main:
    x = 0
    y = 1
    (z, v) = (x, y)
    h = (z, v)
|], -}  named "assignment" [r|
def foo

def main arg1 arg2:
    tuple = self.mkTuple arg1 arg2
    self.foo tuple
    tuple
|], named "following calls" [r|
def foo
def bar
def Int.+ a

def main:
    1 + 2
    foo
    bar
|], named "following calls 2" [r|
def foo

def main:
    foo
    2
|], named "accessors 1" [r|
def foo

def main:
    foo.bar.baz
    2
|], named "accessors 2" [r|
def main arg:
    arg.bar.baz
    2
|], named "accessors 3" [r|
def x

def main arg:
    x.zooo 43
    -2
|], named "accessors 4" [r|
def x

def main arg:
    x
    x.y
    x.z
|], named "accessors 5" [r|
def main arg:
    x = 4
    x.zooo 43
|], named "accessors 6" [r|
def foo

def main arg:
    foo.bar
|], named "accessors and assignment" [r|
def foo

def main:
    x = foo.bar.baz
    2
|], named "accessors and apps 1" [r|
def foo

def main arg:
    foo.bar arg
    2
|], named "accessors and apps 2" [r|
def foo

def main arg:
    foo.bar arg 2
|], named "complicated inline calls" [r|
def foo

def main arg:
    x = foo.bar(arg, 15, arg, [19..]).baz arg 2
|], named "ranges" [r|
def main arg:
    x = (1, [1..10], [9..])
|], named "prints" [r|
def print

def main arg arg2:
    print arg
    print arg2
    self.bla "kota" "albo nie"
|], named "constructors 1" [r|
class Foo

def main arg:
    Foo.foo 1 2 3
|], named "constructors 2" [r|
class Foo

def main arg:
    Foo 1 2 3
|], named "constructors 3" [r|
class Foo

def main arg:
    Foo arg.boo 1
|], named "constructors 4" [r|
class Foo
class My
def gap

def main arg:
    Foo arg.boo My gap
|], named "tuples 1" [r|
def main arg:
    (1, 2)
    3, 4
    5
|], named "tuples 2" [r|
def main arg:
    x = 4
    y = 1, x
|], named "tuples 3" [r|
def print msg

def main:
    print (1, 2)
|], named "tuples 4" [r|
def print msg

def main:
    x = 1
    print (x, 2)
|], named "lists" [r|
def main arg:
    x = 4
    y = [1, x]
|], named "hello world" [r|
foreign haskell def print msg:
    autoLift1 print msg

def main:
    hello = "hello"
    world = "world"
    print hello
    print world
|]]

---------------------------------------------------------------------------
---- DOES NOT WORK YET: ---------------------------------------------------
---------------------------------------------------------------------------

-- |], named "if-else" [r|
-- def print
--
-- def main arg:
--     print $ if 1 > 2: 5
--             else: 6
--     print $ 1 > 2


-- sampleLambdas :: [(Name, Breadcrumbs, Code)]
-- sampleLambdas = [
--     ( "simple lambda"
--     , [Crumb.Module "Main", Crumb.Function (Name.single "main") [], Crumb.Lambda 6]
--     , [r|
-- def main:
--     f = a : a , 1
-- |]), ( "lambda with context"
--     , [Crumb.Module "Main", Crumb.Function (Name.single "main") [], Crumb.Lambda 12]
--     , [r|
-- def main arg:
--     x = 15
--     f = a : a , 1 , x , arg
-- |])
--     ]


emptyMain :: Code
emptyMain = [r|
def main
def foo
def bar
def baz
def gaz
def a
|]


zipperTestModule :: Code
zipperTestModule = [r|
class Vector a:
    x,y,z :: a

    def test a b:
        (a, b, c : c, a, b)

    class Inner:
        def inner a b:
            a, b

def main:
    v = Vector 1 2 3
    v.test
|]
