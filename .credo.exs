%{
  configs: [
    %{
      name: "default",
      files: %{
        #
        included: [
          "lib/",
          "src/",
          "support/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/support/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        # Enabled by default (and kept unmodified)
        #
        # - Consistency: LineEndings, ExceptionNames, SpaceAroundOperators,
        #   SpaceInParentheses, TabsOrSpaces, UnusedVariableNames
        # - Design: TagFIXME
        # - Readability: AliasOrder, FunctionNames, MaxLineLength, ModuleAttributeNames,
        #   ModuleDoc, ModuleNames, ParenthesesInCondition, ParenthesesOnZeroArityDefs,
        #   PipeIntoAnonymousFunctions, PredicateFunctionNames, PreferImplicitTry,
        #   RedundantBlankLines, Semicolons, SpaceAfterCommas, StrictModuleLayout,
        #   StringSigils, TrailingBlankLine, TrailingWhiteSpace,
        #   UnnecessaryAliasExpansion, VariableNames, WithSingleClause
        # - Refactor.Apply, CondStatements, CyclomaticComplexity, FilterCount,
        #   FilterFilter, FunctionArity, MapJoin, MatchInCondition,
        #   NegatedConditionsInUnless, NegatedConditionsWithElse, Nesting,
        #   RedundantWithClauseResult, RejectReject, UnlessWithElse, WithClauses
        # - Warning.ApplicationConfigInModuleAttribute, BoolOperationOnSameValues, Dbg,
        #   ExpensiveEmptyEnumCheck, IExPry, IoInspect, MissedMetadataKeyInLoggerConfig,
        #   OperationOnSameValues, OperationWithConstantResult, RaiseInsideRescue,
        #   SpecWithStruct, StructFieldAmount, UnsafeExec, UnusedEnumOperation,
        #   UnusedFileOperation, UnusedKeywordOperation, UnusedListOperation,
        #   UnusedMapOperation, UnusedPathOperation, UnusedRegexOperation,
        #   UnusedStringOperation, UnusedTupleOperation, WrongTestFilename

        extra: [
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.ParameterPatternMatching, [force: :after]},
          {Credo.Check.Design.AliasUsage, [:low, if_nested_deeper_than: 2]},
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Design.TagTODO, false},
          {Credo.Check.Readability.AliasAs, false},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.LargeNumbers, [only_greater_than: 9999]},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, [min_pipeline_length: 3]},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          # I'm debating disabling this rule because of how Enviable works.
          {Credo.Check.Readability.OnePipePerLine, []},
          {Credo.Check.Readability.PreferUnquotedAtoms, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, false},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.ABCSize, false},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.CondInsteadOfIfElse, false},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, false},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          # I'm debating disabling this rule because of how Enviable works.
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.UtcNowTruncate, []},
          {Credo.Check.Refactor.VariableRebinding, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, []},
          {Credo.Check.Warning.WrongTestFileExtension, []}
        ]
      }
    }
  ]
}
