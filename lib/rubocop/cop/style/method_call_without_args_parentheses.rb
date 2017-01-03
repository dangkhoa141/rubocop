# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop checks for unwanted parentheses in parameterless method calls.
      #
      # @example
      #   # bad
      #   object.some_method()
      #
      #   # good
      #   object.some_method
      class MethodCallWithoutArgsParentheses < Cop
        MSG = 'Do not use parentheses for method calls with ' \
              'no arguments.'.freeze

        ASGN_NODES = [:lvasgn, :masgn] + SHORTHAND_ASGN_NODES

        def on_send(node)
          _receiver, method_name, *args = *node

          # methods starting with a capital letter should be skipped
          return if method_name =~ /\A[A-Z]/
          return unless args.empty? && node.loc.begin
          return if same_name_assignment?(node)
          return if lambda_call_syntax?(node)
          return if node.keyword_not?

          add_offense(node, :begin)
        end

        def autocorrect(node)
          lambda do |corrector|
            corrector.remove(node.loc.begin)
            corrector.remove(node.loc.end)
          end
        end

        private

        def same_name_assignment?(node)
          _receiver, method_name, *_args = *node

          any_assignment?(node) do |asgn_node|
            if asgn_node.masgn_type?
              next variable_in_mass_assignment?(method_name, asgn_node)
            end

            asgn_node.loc.name.source == method_name.to_s
          end
        end

        def any_assignment?(node)
          node.each_ancestor(*ASGN_NODES).any? do |asgn_node|
            # `obj.method = value` parses as (send ... :method= ...), and will
            # not be returned as an `asgn_node` here, however,
            # `obj.method ||= value` parses as (or-asgn (send ...) ...)
            # which IS an `asgn_node`. Similarly, `obj.method += value` parses
            # as (op-asgn (send ...) ...), which is also an `asgn_node`.
            if asgn_node.or_asgn_type? || asgn_node.and_asgn_type? ||
               asgn_node.op_asgn_type?
              asgn_node, _value = *asgn_node
              next if asgn_node.send_type?
            end

            yield asgn_node
          end
        end

        def variable_in_mass_assignment?(variable_name, node)
          mlhs_node, _mrhs_node = *node
          var_nodes = *mlhs_node

          var_nodes.map { |n| n.to_a.first }.include?(variable_name)
        end

        # don't check `lambda.()` syntax; the Style/LambdaCall cop does that
        def lambda_call_syntax?(node)
          node.method_name == :call && node.loc.selector.nil?
        end
      end
    end
  end
end