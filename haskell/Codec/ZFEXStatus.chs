{-# LANGUAGE ForeignFunctionInterface #-}

module Codec.ZFEXStatus where

#include "zfex_status.h"

{#enum zfex_status_code_t as StatusCode {underscoreToCase} deriving (Show, Eq) #}
