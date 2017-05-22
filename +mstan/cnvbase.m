function out = cnvbase( varargin )
%CNVBASE Convert from one arbitrary base & encoding to another
% -------------------------------------------------------------------------
% Usage:
%   out = cnvbase( in, inBase, outBase )
% Inputs:
%   in      - char / integer / double array defining input number
%   inBase  - definition of input base encoding, in same type as in
%   outBase - definition of output base encoding
% Outputs:
%   out     - value encoded in outBase with matching type
% Description:
%   This converts from one base to another.  This can be used to convert
%   from standard bases like binary and decimal or more exotic bases
%   like base-3.  Only integer numbers are handled.
%
%   The output encoding can also be set.  You could encode in binary
%   using 1s & 0s or Xs and Os.
%
%   The order of appearence in the base encoding is the ranking.  A base
%   of '0123456789' is very different from a base of '9876543210'
% Examples:
%   '1001010' = cnvbase('74','0123456789','01')
%   'XOOXOXO' = cnvbase('74','0123456789','OX')
% -------------------------------------------------------------------------

% Title: Convert between arbitrary bases and encodings
% Author: Robert Kagy
% Matlab Release: Tested on R13SP1

% Verify input & exit if problems are found
[bExit, in, inBase, outBase] = sVerifyInput( varargin{:} );
if strcmp(bExit,'Quit')
    out = [];
    return;
elseif strcmp(bExit,'SelfTest')
    out = [];
    sSelfTest;
    return;
elseif strcmp(bExit,'FcnH')
    out = sFcnH;
    return;
else
    % Convert from custom encoding to array of integers
    inArray = sConvertToUniform(in, inBase);
    
    % Convert from inBase to outBase
    outArray = sConvertBases(inArray, length(inBase), length(outBase));
    
    % Convert from array of integers to custom encoding
    out = sConvertFromUniform(outArray, outBase);
end



% -------------------------------------------------------------------------
function [bExit, in, inBase, outBase] = sVerifyInput( varargin )
% Verify the input from the command line is syntaxtically correct

% Initialize outputs
bExit = 'Quit';
in = [];
inBase = [];
outBase = [];

if nargin == 0
    % Run the self test
    bExit = 'SelfTest';
    return;
elseif nargin == 1
    if ischar(varargin{1})
        if strcmp('FcnH',varargin{1})
            bExit = 'FcnH';
            return;
        else
            % Display problem and exit
            disp(['cnvbase requires exactly 3 inputs, but you provided ',int2str(nargin)]);
            return;
        end
    else
        % Display problem and exit
        disp(['cnvbase requires exactly 3 inputs, but you provided ',int2str(nargin)]);
        return;
    end
elseif nargin ~= 3
    % Display problem and exit
    disp(['cnvbase requires exactly 3 inputs, but you provided ',int2str(nargin)]);
    return;
else
    % Divide up varargin
    in = varargin{1};
    inBase = varargin{2};
    outBase = varargin{3};
end

% Ensure in & inBase are of the same class
if ~strcmp(class(in),class(inBase))
    % Display problem and exit
    disp(sprintf('cnvbase requires in & inBase be of the same class\n\tClass of in: %s\n\tClass of inBase: %s', ...
        class(in), class(inBase)));
    return;
end

% Ensure that all 3 are of valid classes
VALID_CLASSES = {'double','logical','char','int8','uint8','int16','uint16','int32','uint32'};
if ~ismember(class(in),VALID_CLASSES)
    % Display problem and exit
    disp(['in is of class ',class(in),' which is not supported']);
    return;
elseif ~ismember(class(inBase),VALID_CLASSES)
    % Display problem and exit
    disp(['inBase is of class ',class(inBase),' which is not supported']);
    return;
elseif ~ismember(class(outBase),VALID_CLASSES)
    % Display problem and exit
    disp(['outBase is of class ',class(outBase),' which is not supported']);
    return;
end

% Ensure all elements of in are members of set inBase
if ~min(ismember(in,inBase))
    % Display problem and exit
    strErr = sprintf('inBase is not a superset of in\nValues not members of inBase:\n');
    switch class(in)
        case 'char'
            strErr = [strErr, setdiff(in,inBase)];
        case {'double','logical'}
            strErr = [strErr, num2str(setdiff(in,inBase))];
        otherwise
            strErr = [strErr, num2str(double(setdiff(in,inBase)))];
    end
    disp(strErr);
    return;
end

% Ensure can use intermediate encoding
MAX_LENGTH = 2^32-1;
if length(inBase) > MAX_LENGTH
    % Display problem and exit
    disp(['Max base handled is ',int2str(MAX_LENGTH),...
            ' but inBase is of length ',int2str(length(inBase))]);
    return;
elseif length(outBase) > MAX_LENGTH
    % Display problem and exit
    disp(['Max base handled is ',int2str(MAX_LENGTH),...
            ' but inBase is of length ',int2str(length(outBase))]);
    return;
end

% Ensure all elements are unique
if length(inBase) ~= length(unique(inBase))
    % Display problem and exit
    disp(['Not all elements of inBase are unique, invalid base']);
    return;
elseif length(outBase) ~= length(unique(outBase))
    % Display problem and exit
    disp(['Not all elements of inBase are unique, invalid base']);
    return;
end

% Made it so don't exit
bExit = 'Go';



% -------------------------------------------------------------------------
function inArray = sConvertToUniform(in, inBase)
% Convert from custom base to integer array

% Initialize inArray
inArray = [];

% Loop through each array element
for idx=1:length(in)
    inArray = [inArray, find(in(idx) == inBase)];
end



% -------------------------------------------------------------------------
function out = sConvertFromUniform(outArray, outBase)
% Convert from integer array to custom base

% Create empty array of same class as outBase
switch class(outBase)
    case 'double'
        out = [];
    case 'logical'
        out = logical([]);
    case 'char'
        out = char([]);
    case 'int8'
        out = int8([]);
    case 'int16'
        out = int16([]);
    case 'int32'
        out = int32([]);
    case 'uint8'
        out = uint8([]);
    case 'uint16'
        out = uint16([]);
    case 'uint32'
        out = uint32([]);
    otherwise
        error(['sConvertFromUniform doesn''t support the ',...
                class(outBase),' class!']);
end

% Convert one element at a time
for idx=1:length(outArray)
    out = [out, outBase(outArray(idx))];
end



% -------------------------------------------------------------------------
function outArray = sConvertBases(inArray, inBase, outBase)
% convert integer array from inBase to outBase

% Check for simple case
if inBase == outBase
    outArray = inArray;
    return;
end

% Convert from array to array
%   Less change of precision loss by
%   working with one digit at a time

% Remove offset from inArray
inArray = inArray - 1;

% Initialize accumulator
outArray = [];

% Loop through digits
for idx = length(inArray):-1:1
    % Get current digit and power
    cDigit = inArray(idx);
    cPower = length(inArray) - idx;
    
    % Raise input base to power as represented in destination base
    arrPower = sPowArbBases(inBase, cPower, outBase);
    
    % Convert current digit to destination base
    arrDigit = sConvertVal2Base(cDigit, outBase);
    
    % Multiply current digit by current power
    %   All as represented in destination base
    arrValue = sMultArbBases(arrPower, arrDigit, outBase);
    
    % Add current digits value to accumulator
    %   All as represented in destination base
    outArray = sAddArbBases(outArray, arrValue, outBase);
end

% Add offset to outArray
outArray = outArray + 1;




% -------------------------------------------------------------------------
function res = sConvertVal2Base(value, base)
% Converts a value to an integer array

% Initialize output
res = [];

% Loop until complete
while value > 0.5
    remainder = rem(value, base);
    res = [remainder, res];
    value = fix( (value-remainder) / base );
end



% -------------------------------------------------------------------------
function res = sAddArbBases(arr1, arr2, base)
% This function adds two numbers defined as arrays of a certain base

% Initialize output
res = [];
carry = 0;

% Loop through arrays matching parts
commonLen = min(length(arr1),length(arr2));
for idx=1:commonLen
    % Calculate current array position
    cPos1 = length(arr1) - idx + 1;
    cPos2 = length(arr2) - idx + 1;
    
    % Calculate the value in this position
    val = carry + arr1(cPos1) + arr2(cPos2);
    
    % Calculate value for this position & carry
    vPos = rem(val,base);
    carry = (val-vPos) / base;
    
    % Store and move on
    res = [vPos, res];
end

% Continue with longer array
if length(arr1) > length(arr2)
    for idx=1:(length(arr1)-commonLen)
        % Calculate current array position
        cPos = length(arr1) - commonLen - idx + 1;
        
        % Calculate the value in this position
        val = carry + arr1(cPos);
        
        % Calculate value for this position & carry
        vPos = rem(val,base);
        carry = (val-vPos) / base;
        
        % Store and move on
        res = [vPos, res];
    end
elseif length(arr2) > length(arr1)
    for idx=1:(length(arr2)-commonLen)
        % Calculate current array position
        cPos = length(arr2) - commonLen - idx + 1;
        
        % Calculate the value in this position
        val = carry + arr2(cPos);
        
        % Calculate value for this position & carry
        vPos = rem(val,base);
        carry = (val-vPos) / base;
        
        % Store and move on
        res = [vPos, res];
    end
end

% Add carry to end if still there
res = [sConvertVal2Base(carry, base), res];



% -------------------------------------------------------------------------
function res = sMultArbBases(arr1, arr2, base)
% This function multiplies two numbers defined as arrays of a certain base

% Initialize output
res = [0];

% Loop through digits in 2nd
for idx=1:length(arr2)
    % Find current digit and offset
    cOff = idx-1;
    cDig = arr2(length(arr2)-cOff);
    
    % Multiple that arr1 by that digit
    cVal = sMultArrByDigit(arr1, cDig, cOff, base);
    
    % Add result of multiply to accumulator
    res = sAddArbBases(res, cVal, base);
end



% -------------------------------------------------------------------------
function res = sMultArrByDigit(arr, val, offset, base)
% This function multiplies an array and a single value

% Initialize output
res = zeros(1,offset);
carry = 0;

% Multiply each digit in array
for idx=1:length(arr)
    % Find current digit
    cDig = arr(length(arr)-idx+1);
    
    % Calculate the value in this position
    cVal = (val * cDig) + carry;
    
    % Calculate value for this position & carry
    vPos = rem(cVal,base);
    carry = (cVal-vPos) / base;
    
    % Store and move on
    res = [vPos, res];
end

% Add carry to end if still there
res = [sConvertVal2Base(carry, base), res];



% -------------------------------------------------------------------------
function res = sPowArbBases(value, pow, base)
% This function raises a number to a power and outputs
%   an integer array in the desired base

% Check for 0
if pow == 0
    res = 1;
else
    % Convert value to desired base
    x = sConvertVal2Base(value, base);
    
    % Initialize output
    res = 1;
    
    % Keep going until pow is zero
    while pow > 0
        % Handle odd power by multiplication
        if fix(pow/2) ~= (pow/2)
            res = sMultArbBases(res, x, base);
            if pow == 1
                return;
            else
                pow = pow - 1;
            end
        end
        
        % Handle even power by squaring
        x = sMultArbBases(x, x, base);
        pow = pow / 2;
    end
end



% -------------------------------------------------------------------------
function sSelfTest
% Perform a self test / demo

% Intro
tic;
disp('cnvbase can convert between number bases on arbitrary large numbers');
disp('   Usage: cnvbase(valArray, inBase, outBase)');
disp(' ');
disp('-------- SELF TEST --------------');
disp('Same base:');
disp(['  cnvbase(''101'',''01'',''01'') = ', cnvbase('101','01','01')]);
disp(['  cnvbase(''101'',''01'',''AB'') = ', cnvbase('101','01','AB')]);
disp('dec2hex:');
disp(['  dec2hex(3645) = ',dec2hex(3645)]);
disp(['  cnvbase(''3645'',''0123456789'',''0123456789ABCDEF'') = ',...
        cnvbase('3645','0123456789','0123456789ABCDEF')]);
disp('hex2dec:');
disp(['   hex2dec(''F304FCA'') = ', int2str(hex2dec('F304FCA'))]);
disp(['   cnvbase(''F304FCA'',''0123456789ABCDEF'',''0123456789'') = ', ...
        cnvbase('F304FCA','0123456789ABCDEF','0123456789')]);
disp('Large Number:');
disp(['   cnvbase(''FEDCBA9876543210'',''0123456789ABCDEF'',''01'') = ', ...
        cnvbase('FEDCBA9876543210','0123456789ABCDEF','01')]);
disp(['   cnvbase([''2'',int2str(2^53)],''0123456789'',''0123456789ABCDEF'') = ', ...
        cnvbase(['2',int2str(2^53)],'0123456789','0123456789ABCDEF')]);
disp('Strange Bases:');
disp(['   cnvbase(''3021'',''0123'',''012'') = ', ...
        cnvbase('3021','0123','012')]);
disp(['   cnvbase(''FEDCBA9876543210'',''0123456789ABCDEF'',''0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%&*_+='') = ',...
        cnvbase('FEDCBA9876543210','0123456789ABCDEF','0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%&*_+=')]);
delta = toc;
disp(['Time to run Self Test: ', num2str(delta)]);



% -------------------------------------------------------------------------
function res = sFcnH
% Return a structure with function handles to all internal functions
% Useful for debugging
res = struct(...
    'cnvbase', @cnvbase, ...
    'sAddArbBases', @sAddArbBases, ...
    'sConvertBases', @sConvertBases, ...
    'sConvertFromUniform', @sConvertFromUniform, ...
    'sConvertToUniform', @sConvertToUniform, ...
    'sConvertValToBase', @sConvertValToBase, ...
    'sFcnH', @sFcnH, ...
    'sMultArbBases', @sMultArbBases, ...
    'sMultArrByDigit', @sMultArrByDigit, ...
    'sPowArbBases', @sPowArbBases, ...
    'sSelfTest', @sSelfTest, ...
    'sVerifyInput', @sVerifyInput ...
    );