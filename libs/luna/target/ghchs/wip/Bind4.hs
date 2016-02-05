{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeOperators             #-}



{-# LANGUAGE DeriveDataTypeable        #-}
{-# LANGUAGE OverlappingInstances      #-}
{-# LANGUAGE UndecidableInstances      #-}

--{-# LANGUAGE DysfunctionalDependencies #-}




module Bind2 where

import           Control.Applicative
import           Control.Monad.IO.Class
import           Control.Monad.Trans
--import Control.Monad.State

import           Luna.Target.HS.Monad

--import Control.Monad.Trans.State
import           Luna.Target.HS.Utils.BaseMonads

import           Control.Monad.Morph
import           Data.Typeable                   (Typeable)
import           Flowbox.Utils

import           Data.TypeLevel.Bool
import           TypeSet

------------------------------------------------------------------------------------------

class MonadMorph m n where
    morph :: m a -> n a

instance MonadMorph IO IO where
    morph = id

instance MonadMorph Pure Pure where
    morph = id

instance MonadMorph Pure IO where
    morph = return . fromPure



--instance Class Data where
--    func =


class BindEnv m1 m2 m3 | m1 m2 -> m3 where
    bindEnv :: m1 a -> (Pure a -> m2 b) -> m3 b

instance BindEnv Pure Pure Pure where
    bindEnv a f = f a

instance BindEnv IO Pure IO where
    bindEnv ma f = do
        a <- ma
        let Pure b = f (Pure a)
        return b

instance BindEnv Pure IO IO where
    bindEnv a f = f a

instance BindEnv IO IO IO where
    bindEnv ma f = do
        a <- ma
        f (Pure a)

-----
-- (MonadReader t1 (t2 (t3 Pure)), MonadState t (t2 (t3 Pure)), MonadTrans t3, MonadTrans t2, Monad (t3 Pure)) => t2 (t3 Pure) Int


-- instance BindEnv (IC2 t) (IC2 t) (IC2 t) where
--     bindEnv = undefined
--
-- instance  BindEnv (IC2 t1) (IC2 (c2 t2)) tx  =>BindEnv (IC2 (c1 t1)) (IC2 (c2 t2)) (IC2 (c1 tx))  where
--     bindEnv = undefined

-- instance BindEnv t t t where
--     bindEnv = undefined

    -- instance BindEnv Pure Pure Pure where
    --     bindEnv = undefined
    --
    -- instance BindEnv IO IO IO where
    --     bindEnv = undefined
    --
    -- instance BindEnv Pure IO IO where
    --     bindEnv = undefined
    --
    -- instance BindEnv IO Pure IO where
    --     bindEnv = undefined
    --
    -- instance  (BindEnv t1 (c2 t2) tx, Monad t1, Monad t2) =>BindEnv (c1 t1) (c2 t2) (c1 tx)  where
    --     bindEnv = undefined
    --
    -- instance  (Monad t1, out~(c1 t1)) =>BindEnv (c1 t1) t1 out  where
    --     bindEnv = undefined
    -- --
    -- instance  (Monad t1, out~(c2 t1))  =>BindEnv t1 (c2 t1) out  where
    --     bindEnv = undefined

-- instance  (envout ~ EnvMerge env1 env2, setout ~ Union set1 set2) =>BindEnv (MonadSet env1 set1) (MonadSet env2 set2) (MonadSet envout setout)  where
--     bindEnv ma f = MonadSet $ (fromMS ma) >>= (fromMS . f . Pure)

instance  (envout ~ EnvMerge env1 env2, setout ~ Union set1 set2, m1~m2, Monad m1) =>BindEnv (MonadSet env1 set1 m1) (MonadSet env2 set2 m2) (MonadSet envout setout m1)  where
    bindEnv ma f = MonadSet $ (fromMS ma) >>= (fromMS . f . Pure)


instance  (envout ~ EnvMerge env Pure, Monad m) =>BindEnv (MonadSet env set m) Pure (MonadSet envout set m)  where
    bindEnv ma f = MonadSet $ (fromMS ma) >>= (return . fromPure . f . Pure)

instance BindEnv Pure (MonadSet env set m) (MonadSet env set m) where
    bindEnv ma f = f ma

--instance  (envout ~ EnvMerge env Pure, Monad m) =>BindEnv (MonadSet env set m) Pure (MonadSet envout set m)  where
--    bindEnv ma f = MonadSet $ (fromMS ma) >>= (return . fromPure . f . Pure)

-- class FindBase t base | t -> base where
--     findBase :: t a -> base a
--
-- instance FindBase Pure Pure where findBase = undefin

-- class RunMonad m mptr out | m mptr -> out where
--     runMonad :: m -> mptr -> out
--
-- instance  (Remove mptr set setout) =>RunMonad (MonadSet env set m) mptr out  where
--     runMonad = runMonad' (undefined :: IsEmpty setout)
--
--

class MonadSetTrans m out | m -> out where
    liftSet :: m -> out

--instance  (MonadTrans t0, Monad m0) =>MonadSetTrans (MonadSet env () m a) (m0 a0 -> t0 m0 a0)  where
--    liftSet _ = lift

--instance  (Monad m0, MonadTrans t0, (MonadSetTrans(MonadSet env xs m a) (t0 m0 a0 -> t0 m0 a0))) =>MonadSetTrans (MonadSet env (x,xs) m a) (m0 a0 -> t0 m0 a0)  where
--    liftSet _ = (liftSet (undefined :: MonadSet env (xs) m a)) . lift

--dummy
--proxy
--mock

newtype ProxyTrans m a = ProxyTrans (m a)

unproxyTrans ::  (MonadTrans t, Monad m)=>ProxyTrans m a -> t m a
unproxyTrans (ProxyTrans a) = lift a


instance MonadTrans ProxyTrans where
    lift = ProxyTrans

instance  (Monad m) =>MonadSetTrans (MonadSet env () m a) (MonadSet env () (ProxyTrans m) a)  where
    liftSet = MonadSet . lift . fromMS

instance  (Monad m, MonadSetTrans(MonadSet env xs m a) (t m a -> mout a), MonadTrans t) =>MonadSetTrans (MonadSet env (x,xs) m a) (MonadSet env (x,xs) mout a)  where
    liftSet = MonadSet . (liftSet (undefined :: MonadSet env xs m a)) . lift . fromMS






class MatchMonadCloseProto flag m t | flag m -> t where
    matchMonadCloseProto :: flag -> m a -> t a

instance MatchMonadCloseProto False m m where
    matchMonadCloseProto _ = id

instance  (m~env) =>MatchMonadCloseProto True (MonadSet env set m) env  where
    matchMonadCloseProto _ = closeMonadSet


class MatchMonadClose m t | m -> t where
    matchMonadClose :: m a -> t a

instance  (MatchMonadCloseProto emptySet (MonadSet env set ma) out, emptySet ~ IsEmpty set) =>MatchMonadClose (MonadSet env set ma) out  where
    matchMonadClose = matchMonadCloseProto (undefined :: emptySet)


runMonadProto :: mptr -> (ma a -> mb b) -> (MonadSet env set ma a) -> (MonadSet env (Remove mptr set) mb b)
runMonadProto _ f ms = MonadSet $ f (fromMS ms)

runMonad ::  MatchMonadCloseProto (IsEmpty (Remove mptr set)) (MonadSet env (Remove mptr set) mb) t =>mptr -> (ma a -> mb b) -> MonadSet env set ma a -> t b
runMonad = matchMonadClose `dot3` runMonadProto




liftMonadRunner1 mptr f m = flip (runMonad mptr) m . (appLastArg1 f)
liftMonadRunner2 mptr f m = flip (runMonad mptr) m . (appLastArg2 f)
liftMonadRunner3 mptr f m = flip (runMonad mptr) m . (appLastArg3 f)


runStateTX  = liftMonadRunner1 MState runStateT
runReaderTX = liftMonadRunner1 MReader runReaderT



--runStateTX m = flip (runMonad MState) m `dot1` (flip runStateT)



getX ::  MonadState s m=>MonadSet Pure (Insert MState Empty) m s
getX = MonadSet get

askX ::  MonadReader s m=>MonadSet Pure (Insert MReader Empty) m s
askX = MonadSet ask

tstM = getX `bindEnv_` askX
tstM2 = getX `bindEnv_` (Pure(1::Int))
tstM3 = (Pure(1::Int)) `bindEnv_` (Pure(1::Int))
tstM4 = (Pure(1::Int)) `bindEnv_` getX

data MState  = MState  deriving (Show, Typeable)
data MReader = MReader deriving (Show, Typeable)

-- newtype MonadSet (base :: * -> *) set val = MonadSet { fromMS :: val } deriving (Show, Typeable)
newtype MonadSet (base :: * -> *) set m val = MonadSet { fromMS :: m val } deriving (Show, Typeable)


closeMonadSet :: MonadSet base set base a -> base a
closeMonadSet (MonadSet a) = a


type family BaseCtx t where
    BaseCtx Pure  = Pure
    BaseCtx IO    = IO
    BaseCtx (t m) = BaseCtx m

fStatePure = do
    x <- get
    lift (Pure (5::Int))



main = do
    print $ runStateTX getX 0
    print $ runReaderTX (runStateTX (getX `bindEnv_` askX) 0) 5
    print $ tstM3
    -- printType $ getX `bindEnv_` askX
    -- printType $ (undefined :: Pure Int) `bindEnv_` (undefined :: Pure Int)
    -- printType $ (undefined :: StateT Int Pure Int) `bindEnv_` (undefined :: StateT Int Pure Int)
    -- printType $ (undefined :: StateT Int Pure Int) `bindEnv_` (undefined :: Pure Int)
    -- printType $ (undefined :: StateT Int Pure Int) `bindEnv_` (undefined :: ReaderT Int Pure Int)

    putStrLn "----"

    -- printType $ findBase (undefined :: Pure Int)
    -- print $ runStateT (fStatePure `bindEnv_` fStatePure) (0::Int)

    print "end"


-- instance  (t1~t2, Monad (t2 Pure)) =>BindEnv (t1 Pure) (t2 Pure) (t1 Pure)  where
--     bindEnv ma f = do
--         a <- ma
--         f (Pure a)
--
--
-- instance  (Monad (t1 IO), t1~t2) =>BindEnv (t1 IO) (t2 IO) (t1 IO)  where
--     bindEnv ma f = do
--         a <- ma
--         f (Pure a)
--
-- instance  (Monad (t1 IO), t1~t2, MFunctor t2) =>BindEnv (t1 Pure) (t2 IO) (t1 IO)  where
--     bindEnv ma f = do
--         a <- hoist morph ma
--         f (Pure a)
--
-- instance  (Monad (t1 IO), t1~t2, MFunctor t2) =>BindEnv (t1 IO) (t2 Pure) (t1 IO)  where
--     bindEnv ma f = do
--         a <- ma
--         hoist morph $ f (Pure a)
--
-- -----
--
-- instance BindEnv Pure (t Pure) (t Pure) where
--     bindEnv a f = f a
--
--
-- instance BindEnv Pure (t IO) (t IO) where
--     bindEnv a f = f a
--
--
-- instance  (Monad (t IO), MonadTrans t, MFunctor t) =>BindEnv IO (t Pure) (t IO)  where
--     bindEnv ma f = do
--         a <- lift ma
--         hoist morph $ f (Pure a)
--
--
-- instance  (Monad (t IO), MonadTrans t) =>BindEnv IO (t IO) (t IO)  where
--     bindEnv ma f = do
--         a <- lift ma
--         f (Pure a)
--
-- -----
--
-- instance  Monad (t Pure) =>BindEnv (t Pure) Pure (t Pure)  where
--   bindEnv ma f = do
--         a <- ma
--         let Pure b = f (Pure a)
--         return b
--
--
-- instance  (Monad (t IO), MonadTrans t, MFunctor t) =>BindEnv (t Pure) IO (t IO)  where
--     bindEnv ma f = do
--         a <- hoist morph ma
--         lift $ f (Pure a)
--
--
-- instance  Monad (t IO) =>BindEnv (t IO) Pure (t IO)  where
--     bindEnv ma f = do
--         a <- ma
--         let Pure b = f (Pure a)
--         return b
--
-- instance  (Monad (t IO), MonadTrans t) =>BindEnv (t IO) IO (t IO)  where
--     bindEnv ma f = do
--         a <- ma
--         lift $ f (Pure a)

-------------------------------

bindCtx ::  (BindEnv ma mb mout, Context ca, Context cb, Context(CtxMerge ca cb))=>ca ma a -> (Pure a -> cb mb b) -> (CtxMerge ca cb) mout b
bindCtx a f = wrapCtx $ bindEnv (fromCtx a) (fromCtx . f)







-- dodac closed type family do bindCtx po to by determinowac ctx w rezultacie,
-- obecnie funkcja tst zwraca Context c => c IO Int!
-- a potem sprawdzic z reszta funkcji


--testIO :: IO Int
--testIO = do
--    liftIO $ print "dupa jeza"
--    return 5

--testStateT :: StateT Int IO Int
--testStateT = do
--    liftIO $ print "dupa jeza"
--    x <- get
--    put(x+1)
--    return 5


--testStateT2 :: Pure Int -> StateT Int Pure Int
--testStateT2 (Pure x) = do
--    return (x*2)


-- testPure :: Int :> Pure
-- testPure = return 5
--
-- testIO :: Int :> IO
-- testIO = return 5
--
-- --testStatePure :: IC2 (StateT Int Pure) Int
-- --testStatePure :: (MonadState t m, Num b, Monad (IC2 m)) => IC2 m b
testStatePure :: (MonadState t (t1 Pure), MonadTrans t1) => IC2 (t1 Pure) Int
testStatePure = do
    x <- get'
    IC2 $ lift (Pure (5::Int))
--
--
-- testStateIO :: (MonadState t (t1 IO), MonadTrans t1) => IC2 (t1 IO) Int
-- testStateIO = do
--     x <- get'
--     IC2 $ lift (return (5::Int) :: IO Int)
--
testReaderPure :: (MonadReader t (t1 Pure), MonadTrans t1) => IC2 (t1 Pure) Int
testReaderPure = do
    x <- ask'
    IC2 $ lift (Pure (5::Int))
--
-- -- tstM :: StateT Int (ReaderT Int Pure) Int
-- tstM :: (MonadReader t1 (t2 (t3 Pure)), MonadState t (t2 (t3 Pure)), MonadTrans t3, MonadTrans t2, Monad (t3 Pure)) => t2 (t3 Pure) Int
--
-- tstM = do
--     x <- get
--     y <- ask
--     -- lift . lift $ (Pure $ (5::Int))
--     lift $ lift (Pure (5::Int))

--class (Monad m) => MonadState s m | m -> s where
--    get :: m s
--    put :: s -> m ()

--instance  (MonadTrans (t s), Monad (t s m), Monad m, MonadState s (t s m)) =>MonadState s (IC (t s) m)  where
ask' = IC2 $ ask
get' = IC2 $ get
put' = IC2 . put


-- tst = testPure `bindCtx` (\_ ->
--         testIO
--     )
--
-- tst2 = testPure `bindCtx` (\_ ->
--        testStatePure
--    )
--
-- tst3 = testPure `bindCtx` (\_ ->
--        testStateIO
--    )
--
-- tst4 = testStatePure `bindCtx` (\_ ->
--        testStatePure
--    )
--
-- tst5 = testStatePure `bindCtx` (\_ ->
--        testStateIO
--    )
--
-- tst6 = testStatePure `bindCtx` (\_ ->
--        testReaderPure
--    )


--printCtx :: Show s => s :> Pure -> () :> IO
--printCtx s = liftCtx $ print (fromPure $ unliftCtx s)


bindEnv_ a b = bindEnv a (\_ -> b)

--
-- main = do
--     -- print $ runReaderT (runStateT (fromIC2 tstM) (0::Int)) (1::Int)
--     --let x = testStateT `bindEnv` testStateT2
--         --let x = testIO `bindEnv` testStateT2
--         --print =<< runStateT x 5
--
--     --let y = testPure `bind2` printCtx
--     --unliftCtx y
--
--     --let y = testStateT
--     --    z = rebase y :: StateT Int IO Int
--     print "end"






----------------------------------------

--class Bind2 m1 m2 m3 | m1 m2 -> m3 where
--    bind2 :: a :> m1 -> (a :> Pure -> b :> m2) -> b :> m3

--instance Bind2 Pure Pure Pure where
--    bind2 a f = f a

--instance Bind2 IO Pure IO where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        let Pure b = unliftCtx $ f (liftCtx $ Pure a)
--        return b

--instance Bind2 Pure IO IO where
--    bind2 a f = f a

--instance Bind2 IO IO IO where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        unliftCtx $ f (liftCtx $ Pure a)

-----

--instance (Monad (m1 Pure), m1~m2) => Bind2 (m1 Pure) (m2 Pure) (m1 Pure) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        unliftCtx $ f (liftCtx $ Pure a)

--instance (Monad (m1 IO), m1~m2) => Bind2 (m1 IO) (m2 IO) (m1 IO) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        unliftCtx $ f (liftCtx $ Pure a)

--instance (Monad (m1 IO), MonadRebase m1 Pure IO, m1~m2) => Bind2 (m1 Pure) (m2 IO) (m1 IO) where
--    bind2 ma f = liftCtx $ do
--        a <- rebase $ unliftCtx ma
--        unliftCtx $ f (liftCtx $ Pure a)

--instance (Monad (m1 IO), MonadRebase m1 Pure IO, m1~m2) => Bind2 (m1 IO) (m2 Pure) (m1 IO) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        rebase . unliftCtx $ f (liftCtx $ Pure a)

-----

--instance Bind2 Pure (m Pure) (m Pure) where
--    bind2 a f = f a


--instance Bind2 Pure (m IO) (m IO) where
--    bind2 a f = f a


--instance (Monad (m IO), MonadTrans m, MonadRebase m Pure IO) => Bind2 IO (m Pure) (m IO) where
--    bind2 ma f = liftCtx $ do
--        a <- lift . unliftCtx $ ma
--        rebase . unliftCtx $ f (liftCtx $ Pure a)


--instance (Monad (m IO), MonadTrans m) => Bind2 IO (m IO) (m IO) where
--    bind2 ma f = liftCtx $ do
--        a <- lift . unliftCtx $ ma
--        unliftCtx $ f (liftCtx $ Pure a)

-----

--instance Monad (m Pure) => Bind2 (m Pure) Pure (m Pure) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        let Pure b = unliftCtx $ f (liftCtx $ Pure a)
--        return b


--instance (Monad (m IO), MonadTrans m, MonadRebase m Pure IO) => Bind2 (m Pure) IO (m IO) where
--    bind2 ma f = liftCtx $ do
--        a <- rebase . unliftCtx $ ma
--        lift . unliftCtx $ f (liftCtx $ Pure a)


--instance Monad (m IO) => Bind2 (m IO) Pure (m IO) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx ma
--        let Pure b = unliftCtx $ f (liftCtx $ Pure a)
--        return b

--instance (Monad (m IO), MonadTrans m) => Bind2 (m IO) IO (m IO) where
--    bind2 ma f = liftCtx $ do
--        a <- unliftCtx $ ma
--        lift . unliftCtx $ f (liftCtx $ Pure a)
