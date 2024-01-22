alias Credo.Check

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/web/"
        ],
        excluded: [~r"/tests/", ~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          ## Consistency Checks ------------------------------------------------
          {Check.Consistency.ExceptionNames, []},
          {Check.Consistency.LineEndings, []},
          {Check.Consistency.ParameterPatternMatching, []},
          {Check.Consistency.SpaceAroundOperators, []},
          {Check.Consistency.SpaceInParentheses, []},
          {Check.Consistency.TabsOrSpaces, []},

          ## Design Checks -----------------------------------------------------
          {Check.Design.AliasUsage, if_nested_deeper_than: 2},

          ## Readability Checks ------------------------------------------------
          {Check.Readability.AliasOrder, []},
          {Check.Readability.FunctionNames, []},
          {Check.Readability.LargeNumbers, []},
          {Check.Readability.MaxLineLength, priority: :low, max_length: 120},
          {Check.Readability.ModuleAttributeNames, []},
          {Check.Readability.ModuleDoc, []},
          {Check.Readability.ModuleNames, []},
          {Check.Readability.ParenthesesInCondition, []},
          {Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Check.Readability.PipeIntoAnonymousFunctions, []},
          {Check.Readability.PredicateFunctionNames, []},
          {Check.Readability.PreferImplicitTry, []},
          {Check.Readability.RedundantBlankLines, []},
          {Check.Readability.Semicolons, []},
          {Check.Readability.SpaceAfterCommas, []},
          {Check.Readability.StringSigils, []},
          {Check.Readability.TrailingBlankLine, []},
          {Check.Readability.TrailingWhiteSpace, []},
          {Check.Readability.UnnecessaryAliasExpansion, []},
          {Check.Readability.VariableNames, []},
          {Check.Readability.WithSingleClause, []},

          ## Refactoring Opportunities -----------------------------------------
          {Check.Refactor.Apply, []},
          {Check.Refactor.CondStatements, []},
          {Check.Refactor.CyclomaticComplexity, []},
          {Check.Refactor.FunctionArity, []},
          {Check.Refactor.LongQuoteBlocks, []},
          {Check.Refactor.MatchInCondition, []},
          {Check.Refactor.MapJoin, []},
          {Check.Refactor.NegatedConditionsInUnless, []},
          {Check.Refactor.NegatedConditionsWithElse, []},
          {Check.Refactor.Nesting, []},
          {Check.Refactor.UnlessWithElse, []},
          {Check.Refactor.WithClauses, []},
          {Check.Refactor.FilterFilter, []},
          {Check.Refactor.RejectReject, []},
          {Check.Refactor.RedundantWithClauseResult, []},

          ## Warnings ----------------------------------------------------------
          {Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Check.Warning.BoolOperationOnSameValues, []},
          {Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Check.Warning.IExPry, []},
          {Check.Warning.IoInspect, []},
          {Check.Warning.OperationOnSameValues, []},
          {Check.Warning.OperationWithConstantResult, []},
          {Check.Warning.RaiseInsideRescue, []},
          {Check.Warning.SpecWithStruct, []},
          {Check.Warning.WrongTestFileExtension, []},
          {Check.Warning.UnusedEnumOperation, []},
          {Check.Warning.UnusedFileOperation, []},
          {Check.Warning.UnusedKeywordOperation, []},
          {Check.Warning.UnusedListOperation, []},
          {Check.Warning.UnusedPathOperation, []},
          {Check.Warning.UnusedRegexOperation, []},
          {Check.Warning.UnusedStringOperation, []},
          {Check.Warning.UnusedTupleOperation, []},
          {Check.Warning.UnsafeExec, []},

          ## Checks which should always be on for consistency-sake IMO ---------
          {Check.Consistency.MultiAliasImportRequireUse, []},
          {Check.Consistency.UnusedVariableNames, force: :meaningful},
          {Check.Design.DuplicatedCode, []},
          {Check.Design.SkipTestWithoutComment, []},
          {Check.Readability.ImplTrue, []},
          {Check.Readability.MultiAlias, []},
          {Check.Readability.NestedFunctionCalls, []},
          {Check.Readability.SeparateAliasRequire, []},
          {Check.Readability.SingleFunctionToBlockPipe, []},
          {Check.Readability.SinglePipe, []},
          {Check.Readability.StrictModuleLayout, []},
          {Check.Readability.WithCustomTaggedTuple, []},
          {Check.Refactor.ABCSize, [max_size: 55]},
          {Check.Refactor.DoubleBooleanNegation, []},
          {Check.Refactor.FilterReject, []},
          {Check.Refactor.MapMap, []},
          {Check.Refactor.NegatedIsNil, []},
          {Check.Refactor.PipeChainStart, []},
          {Check.Refactor.RejectFilter, []},
          {Check.Refactor.VariableRebinding, []},
          {Check.Warning.LeakyEnvironment, []},
          {Check.Warning.MapGetUnsafePass, []},
          {Check.Warning.MixEnv, []},
          {Check.Warning.UnsafeToAtom, []},

          ## Causes Issues with Phoenix ----------------------------------------
          {Check.Readability.Specs, []},
          {Check.Refactor.ModuleDependencies, [max_deps: 19]},

          ## Optional (move to `disabled` based on app domain) -----------------
          {Check.Refactor.IoPuts, []}
        ],
        disabled: [
          ## Checks which are overly limiting ----------------------------------
          {Check.Design.TagTODO, exit_status: 2},
          {Check.Design.TagFIXME, []},
          {Check.Readability.BlockPipe, []},
          {Check.Readability.AliasAs, []},
          {Check.Refactor.AppendSingleItem, []},

          ## Incompatible with modern versions of Elixir -----------------------
          {Check.Refactor.MapInto, []},
          {Check.Warning.LazyLogging, []}
        ]
      }
    }
  ]
}
