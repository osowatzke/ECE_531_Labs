classdef keyValueInitializer < matlab.System
    methods
        function self = keyValueInitializer(varargin)
            % Assign class value properties with key value pairs
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
end