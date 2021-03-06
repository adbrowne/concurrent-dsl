{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
module DodgerBlue.IO
  (evalDslIO,
   newQueue,
   writeQueue,
   tryReadQueue,
   readQueue)
where

import           DodgerBlue.Types
import           Control.Concurrent.Async
import           Control.Concurrent.STM
import           Control.Monad.Free.Church
import           Control.Monad.IO.Class

newQueue :: (MonadIO m) => m (TQueue a)
newQueue = liftIO newTQueueIO

writeQueue :: (MonadIO m) => TQueue a -> a -> m ()
writeQueue q a = (liftIO . atomically) (writeTQueue q a)

tryReadQueue :: (MonadIO m) => TQueue a -> m (Maybe a)
tryReadQueue q = (liftIO . atomically) (tryReadTQueue q)

readQueue :: (MonadIO m) => TQueue a -> m a
readQueue q = (liftIO . atomically) (readTQueue q)

evalDslIO :: (MonadIO m) =>
  (m () -> IO ()) ->
  CustomCommandStep t m ->
  F (CustomDsl TQueue t) a ->
  m a
evalDslIO runChild stepCustomCommand p = iterM stepProgram p
  where
    stepProgram (DslBase (NewQueue' n)) =
      newQueue >>= n
    stepProgram (DslBase (WriteQueue' q a n)) =
      writeQueue q a >> n
    stepProgram (DslBase (TryReadQueue' q n)) =
      tryReadQueue q >>= n
    stepProgram (DslBase (ReadQueue' q n)) =
      readQueue q >>= n
    stepProgram (DslBase (ForkChild' _childName childProgram n)) = do
      let runner = evalDslIO runChild stepCustomCommand childProgram
      childAsync <- liftIO $ async (runChild runner)
      liftIO $ link childAsync
      n
    stepProgram (DslBase (SetPulseStatus' _status n)) = n -- ignore for now
    stepProgram (DslCustom cmd) =
      stepCustomCommand cmd
