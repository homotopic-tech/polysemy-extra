{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

-- |
-- Module      : Polysemy.Extra
-- License     : MIT
-- Maintainer  : dan.firth@homotopic.tech
-- Stability   : experimental
--
-- Extra convenience functions for polysemy.
module Polysemy.Extra
  ( -- * Input
    contramapInput,
    contramapInputSem,
    contramapInput',
    runInputConstF,

    -- * Output
    mapOutput,
    mapOutputSem,
    mapOutput',
    runOutputMapAsKVStore,

    -- * Raise
    raise4Under,

    -- * Reinterpreters
    reinterpretUnder,
    reinterpretUnder2,
    reinterpret2Under,

    -- * Rotation
    rotateEffects2,
    rotateEffects3L,
    rotateEffects3R,
    rotateEffects4L,
    rotateEffects4R,

    -- * Reverse
    reverseEffects2,
    reverseEffects3,
    reverseEffects4,
  )
where

import Control.Arrow
import Data.Map as Map
import Polysemy
import Polysemy.Input
import Polysemy.Internal
import Polysemy.Internal.Union
import Polysemy.KVStore
import Polysemy.Output

-- | Run an `Output` (`Map` k v) as a `KVStore` by writing the values to
-- the keys.
--
-- @since 0.1.0.0
runOutputMapAsKVStore ::
  Members '[KVStore k v] r =>
  Sem (Output (Map k v) ': r) a ->
  Sem r a
runOutputMapAsKVStore = interpret \case
  Output xs -> mapM_ (uncurry writeKV) (Map.toList xs)
{-# INLINE runOutputMapAsKVStore #-}

-- | Map an `Output` covariantly.
--
-- @since 0.1.0.0
mapOutput ::
  Members '[Output o'] r =>
  -- | A function to map the old output to the new output.
  (o -> o') ->
  Sem (Output o ': r) a ->
  Sem r a
mapOutput f = interpret \case
  Output o -> output (f o)
{-# INLINE mapOutput #-}

-- | Reinterpreting version of `mapOutput`.
--
-- @since 0.1.4.0
mapOutput' ::
  Members '[Output o'] r =>
  -- | A function to map the old output to the new output.
  (o -> o') ->
  Sem (Output o ': r) a ->
  Sem (Output o' ': r) a
mapOutput' f = raiseUnder >>> mapOutput f
{-# INLINE mapOutput' #-}

-- | Map an `Output` covariantly through a monadic function.
--
-- @since 0.1.0.0
mapOutputSem ::
  forall o o' r a.
  Members '[Output o'] r =>
  -- | A function to map the old output to the new output.
  (o -> Sem r o') ->
  Sem (Output o ': r) a ->
  Sem r a
mapOutputSem f = interpret \case
  Output o -> f o >>= output
{-# INLINE mapOutputSem #-}

-- | Map an `Input` contravariantly.
--
-- @since 0.1.0.0
contramapInput ::
  forall i i' r a.
  Members '[Input i'] r =>
  -- | A function to map the new input to the old input.
  (i' -> i) ->
  Sem (Input i ': r) a ->
  Sem r a
contramapInput f = interpret \case
  Input -> f <$> input @i'
{-# INLINE contramapInput #-}

-- | Reinterpreting version of `contramapInput`.
--
-- @since 0.1.4.0
contramapInput' ::
  forall i i' r a.
  Members '[Input i'] r =>
  -- | A function to map the new input to the old input.
  (i' -> i) ->
  Sem (Input i ': r) a ->
  Sem (Input i' ': r) a
contramapInput' f = raiseUnder >>> contramapInput f
{-# INLINE contramapInput' #-}

-- | Map an `Input` contravariantly through a monadic function.
-- @since 0.1.0.0
contramapInputSem ::
  forall i i' r a.
  Members '[Input i'] r =>
  -- | A function to map the new input to the old input.
  (i' -> Sem r i) ->
  Sem (Input i ': r) a ->
  Sem r a
contramapInputSem f = interpret \case
  Input -> f =<< input @i'
{-# INLINE contramapInputSem #-}

-- | Like `runInputConst`, except with a type parameter for the functor for abusing type applications.
--
-- @since 0.1.5.0
runInputConstF ::
  forall b f r a.
  f b ->
  Sem (Input (f b) ': r) a ->
  Sem r a
runInputConstF = runInputConst @(f b)
{-# INLINE runInputConstF #-}

-- | Reinterpret the second effect in the stack into a single effect.
--
-- @since 0.1.1.0
reinterpretUnder ::
  forall e1 e2 e3 r a.
  -- | A natural transformation from the handled effect to the new effects.
  (forall m x. Sem (e2 ': m) x -> Sem (e3 ': m) x) ->
  Sem (e1 ': e2 ': r) a ->
  Sem (e1 ': e3 ': r) a
reinterpretUnder f =
  raise2Under @e1 @e1 @e2
    >>> subsumeUsing @e1 (There Here)
    >>> f
    >>> raise2Under @e3 @e3 @e1
    >>> subsumeUsing @e3 (There Here)
{-# INLINE reinterpretUnder #-}

-- | Reinterpret the third effect in the stack into a single effect.
--
-- @since 0.1.1.0
reinterpretUnder2 ::
  forall e1 e2 e3 e4 r a.
  -- | A natural transformation from the handled effect to the new effects.
  (forall m x. Sem (e3 ': m) x -> Sem (e4 ': m) x) ->
  Sem (e1 ': e2 ': e3 ': r) a ->
  Sem (e1 ': e2 ': e4 ': r) a
reinterpretUnder2 f =
  raise3Under @e1 @e1 @e2 @e3
    >>> subsumeUsing @e1 (There $ There Here)
    >>> raise3Under @e2 @e2 @e3 @e1
    >>> subsumeUsing @e2 (There $ There Here)
    >>> f
    >>> raise3Under @e4 @e4 @e1 @e2
    >>> subsumeUsing @e4 (There $ There Here)
{-# INLINE reinterpretUnder2 #-}

-- | Reinterpret the second effect in the stack in terms of two effects.
--
-- @since 0.1.1.0
reinterpret2Under ::
  forall e1 e2 e3 e4 r a.
  -- | A natural transformation from the handled effect to the new effects.
  (forall m x. Sem (e2 ': m) x -> Sem (e3 ': e4 ': m) x) ->
  Sem (e1 ': e2 ': r) a ->
  Sem (e1 ': e3 ': e4 ': r) a
reinterpret2Under f =
  raise2Under @e1 @e1 @e2
    >>> subsumeUsing @e1 (There Here)
    >>> f
    >>> raise3Under @e3 @e3 @e4 @e1
    >>> subsumeUsing @e3 (There $ There Here)
    >>> raise3Under @e4 @e4 @e1 @e3
    >>> subsumeUsing @e4 (There $ There Here)
{-# INLINE reinterpret2Under #-}

-- | Like `raise`, but introduces an effect four levels underneath the head of the list.
--
-- @since 0.1.3.0
raise4Under :: forall e5 e1 e2 e3 e4 r a. Sem (e1 ': e2 ': e3 ': e4 ': r) a -> Sem (e1 ': e2 ': e3 ': e4 ': e5 ': r) a
raise4Under = hoistSem $ hoist raise4Under . weaken4Under
  where
    weaken4Under :: forall m x. Union (e1 : e2 : e3 : e4 : r) m x -> Union (e1 : e2 : e3 : e4 : e5 : r) m x
    weaken4Under (Union Here a) = Union Here a
    weaken4Under (Union (There Here) a) = Union (There Here) a
    weaken4Under (Union (There (There Here)) a) = Union (There (There Here)) a
    weaken4Under (Union (There (There (There Here))) a) = Union (There (There (There Here))) a
    weaken4Under (Union (There (There (There (There n)))) a) = Union (There (There (There (There (There n))))) a
    {-# INLINE weaken4Under #-}
{-# INLINE raise4Under #-}

-- | Swap the positions of the first two effects in the stack.
--
-- @since 0.1.2.0
rotateEffects2 :: forall e1 e2 r a. Sem (e1 ': e2 ': r) a -> Sem (e2 ': e1 ': r) a
rotateEffects2 = raise2Under >>> subsumeUsing (There Here)
{-# INLINE rotateEffects2 #-}

-- | Rotate the first three effects in the stack to the left.
--
-- @since 0.1.2.0
rotateEffects3L :: forall e1 e2 e3 r a. Sem (e1 ': e2 ': e3 ': r) a -> Sem (e2 ': e3 ': e1 ': r) a
rotateEffects3L = raise3Under >>> subsumeUsing (There $ There Here)
{-# INLINE rotateEffects3L #-}

-- | Rotate the first three effects in the stack to the right.
--
-- @since 0.1.2.0
rotateEffects3R :: forall e1 e2 e3 r a. Sem (e1 ': e2 ': e3 ': r) a -> Sem (e3 ': e1 ': e2 ': r) a
rotateEffects3R = rotateEffects3L >>> rotateEffects3L
{-# INLINE rotateEffects3R #-}

-- | Rotate the first four effects in the stack to the left.
--
-- @since 0.1.3.0
rotateEffects4L :: forall e1 e2 e3 e4 r a. Sem (e1 ': e2 ': e3 ': e4 ': r) a -> Sem (e2 ': e3 ': e4 ': e1 ': r) a
rotateEffects4L = raise4Under >>> subsumeUsing (There $ There $ There Here)
{-# INLINE rotateEffects4L #-}

-- | Rotate the first four effects in the stack to the right.
--
-- @since 0.1.3.0
rotateEffects4R :: forall e1 e2 e3 e4 r a. Sem (e1 ': e2 ': e3 ': e4 ': r) a -> Sem (e4 ': e1 ': e2 ': e3 ': r) a
rotateEffects4R = rotateEffects4L >>> rotateEffects4L >>> rotateEffects4L
{-# INLINE rotateEffects4R #-}

-- | Reverse the position of the first two effects in the stack, equivalent to `rotateEffects2`.
--
-- @since 0.1.3.0
reverseEffects2 :: forall e1 e2 r a. Sem (e1 ': e2 ': r) a -> Sem (e2 ': e1 ': r) a
reverseEffects2 = rotateEffects2
{-# INLINE reverseEffects2 #-}

-- | Reverse the position of the first three effects in the stack.
--
-- @since 0.1.3.0
reverseEffects3 :: forall e1 e2 e3 r a. Sem (e1 ': e2 ': e3 ': r) a -> Sem (e3 ': e2 ': e1 ': r) a
reverseEffects3 = rotateEffects3L >>> rotateEffects2
{-# INLINE reverseEffects3 #-}

-- | Reverse the position of the first four effects in the stack.
--
-- @since 0.1.3.0
reverseEffects4 :: forall e1 e2 e3 e4 r a. Sem (e1 ': e2 ': e3 ': e4 ': r) a -> Sem (e4 ': e3 ': e2 ': e1 ': r) a
reverseEffects4 = rotateEffects4L >>> rotateEffects3L >>> rotateEffects2
{-# INLINE reverseEffects4 #-}
