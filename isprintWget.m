function records = isprintWget(cgiUrl, file, parms, user_fullname, user_email, user_affiliation, filters, outputFile, missing, assumed, knownbad)
%  isprintWget - Private method to create an isprint-like 3D array of
%  doubles via a command
%  similar to the isprint command-line application, but access data via
%  wget.  Meant to be a private function - call isprintWeb instead, which
%  will call this method indirectly.
%
%  This method differs from isprintWeb in that wget is used to download the
%  data.  Throws error if wget not found, but not if timeout occurs.  The
%
%  The calling syntax for this method is:
%
%  		[records] = isprintWget(cgiurl, file, parms, user_fullname, user_email, user_affiliation, [filters, [outputFile, [missing, [assumed, [knownbad] ] ] ] ])
%
%   where
%
%     cgiurl (string) to Madrigal site cgi directory that has that
%      filename.
%        (Example: 'http://madrigal.haystack.mit.edu/cgi-bin/madrigal/')
%         Note that method getMadrigalCgiUrl converts homepage url into cgiurl.
%
%     file is path to file
%         (example = '/home/brideout/data/mlh980120g.001')
%
%     parms is the desired parameters in the form of a comma-delimited
%         string of Madrigal mnemonics (example = 'gdlat,ti,dti')
%
%     user_fullname - is user name (string)
%
%     user_email - is user email address (string)
%
%     user_affiliation - is user affiliation (string)
%
%     filters is the optional filters requested in exactly the form given in isprint
%         command line (example = 'time1=15:00:00 date1=01/20/1998
%                       time2=15:30:00 date2=01/20/1998 filter=ti,500,1000')
%         See:  http://millstonehill.haystack.mit.edu/ug_commandLine.html for details
%
%     outputFile - save the output to an output file.  If externsion is in
%       .h5, .hdf, or .hdf5, the output format will be Madrigal Hdf5.  If
%       extension is .nc, it will be netCDF4.  Otherwise ascii.
%
%     missing is an optional double to represent missing values.  Defaults to NaN
%
%     assumed is an optional double to represent assumed values.  Defaults to NaN
%
%     knownbad is an optional double to represent knownbad values.  Defaults to NaN
%
%     If outputFile not given, then the returned records is a three dimensional array
%     of double with the dimensions:
%
%         [Number of rows, number of parameters requested, number of records]
%
%     If outputFile given, file will be stored as received and not parsed
%     into an array. Returned records is then set to 0.
%
%     If error or no data returned, will return error explanation string instead.
%
%   Example: data = isprintWget('http://madrigal.haystack.mit.edu/cgi-bin/madrigal/', ...
%                                '/opt/madrigal/experiments/1998/mlh/07jan98/mil980107g.001', ...
%                                'gdlat,ti,dti', ...
%                                'Bill Rideout', 'wrideout@haystack.mit.edu', 'MIT');
%
%
%    $Id: isprintWget.m 6811 2019-03-28 19:13:46Z brideout $
arguments
    cgiUrl (1,1) string
    file (1,1) string
    parms (1,1) string
    user_fullname (1,1) string
    user_email (1,1) string
    user_affiliation (1,1) string
    filters (1,1) string = ""
    outputFile (1,1) string = ""
    missing (1,1) {mustBeNumeric} = NaN
    assumed (1,1) {mustBeNumeric} = NaN
    knownbad (1,1) {mustBeNumeric} = NaN
end

% verify wget installed before we do anything
% try to use wget
result = system('curl -h');
if (result ~= 0)
   error('Madmatlab:WgetFailed', ...
       'Unable to run curl - please make sure its installed')
end

% be sure cgiUrl ends with /
if ~endsWith(cgiUrl, "/")
    cgiUrl = cgiUrl + "/";
end

% build the complete cgi string, replacing characters as required by cgi standard
cgiUrl = cgiUrl + "isprintService.py?file=" + strrep(file, "/", "%2F");
% parm + to %2B
parms = strrep(parms, "+", "%2B");
if (length(outputFile) > 1)
    cgiUrl = cgiUrl + "&header=n&parms=" + strrep(parms,',','+');
else
    cgiUrl = cgiUrl + "&header=t&parms=" + strrep(parms,',','+');
end
cgiUrl = cgiUrl + "&user_fullname=" + strrep(user_fullname,' ','+') + ...
        '&user_email=' + user_email + "&user_affiliation=" + strrep(user_affiliation,' ','+');

if length(filters) > 1
    % the filter string requires the following conversions...
    % = to %3D
    filters = strrep(filters,'=','%3D');
    % , to %2C
    filters = strrep(filters,',','%2C');
    % / to %2F
    filters = strrep(filters,'/','%2F');
    % + to %2B
    filters = strrep(filters,'+','%2B');
    % space to +
    filters = strrep(filters,' ','+');
    cgiUrl = cgiUrl + "&filters=" + filters;
end

if strlength(outputFile) > 1
    [~,name,ext] = fileparts(outputFile);
    cgiUrl = strcat(cgiUrl, '&output=', name, ext);
    useStdOut = 0;
else
    % save to a random text file if not set by user
    outputFile = fullfile(tempdir, sprintf('junk%i.txt', randi(1000000000,1)));
    useStdOut = 1;
end

wget_command = "wget -q --timeout=600 --tries=1 -O " + outputFile + ' "' + cgiUrl + '"';
curl_command = "curl --connect-timeout 10 --max-time 600 --speed-limit 100000 --speed-time 30 --retry 1 -L --output " + outputFile + ' "' + cgiUrl + '"';

% try to download
disp(curl_command)
tic;
result = system(curl_command);
if result ~= 0
    if (toc > 590)
        % Assume simply timed out
        disp('Timeout occured');
        records = -1;
        return;
    else
        error('Madmatlab:WgetFailed', "Download command failed: " + curl_command)
    end
end


if (useStdOut ~= 0)
    % remove temp file
    delete(outputFile);
else
    % no need to parse, all set to return
    records = 0;
    return;
end


% now parse the isprint output into a 3D array of doubles

% the first parse is simply to get dimensions

commaMarks = regexp(parms, ',');
numParms = length(commaMarks) + 1;

% get all new lines
lineMarks = regexp(text, '\n');
numRecords = 0;
max2D = 0;
presentStart = 1;
atStart = 1;
lastLine = 0;
% loop through each line
for line = 1:length(lineMarks)
    thisLine = text(presentStart:lineMarks(line));
    presentStart = lineMarks(line) + 1;
    if contains(thisLine, ':')
        % header found
        numRecords = numRecords + 1;
        % see if its the biggest
        if (atStart ~= 1 & (line - lastLine) - 3 > max2D)
            max2D = (line - lastLine) - 3;
        end
        atStart = 0;
        lastLine = line;
    end
    % handle last line
    if line == length(lineMarks)
       if ((line - lastLine) - 2 > max2D)
            max2D = (line - lastLine) - 2;
       end
    end
end

% check that some data was returned
if numRecords == 0 | max2D == 0 | numParms == 0
    records = text;
    return;
end

% create the three dimensional array
records = zeros(max2D, numParms, numRecords);
records(:,:,:) = missing;

% the next parse is to populate records
% get all new lines
lineMarks = regexp(text, '\n');
presentStart = 1;
thisRecord = 1;
this2D = 0;
% thisParm = 0;
% isNewRecord = 1;
% isNew2D = 1;
for line=1:length(lineMarks)
    % get next line
    newLine = text(presentStart:lineMarks(line));
    presentStart = lineMarks(line) + 1;
    % check if its a new record
    if line > 2 & length(newLine) < 2
       this2D = 0;
       thisRecord = thisRecord + 1;
       continue;
    elseif length(newLine) < 2
       % ignore first empty line
       continue;
    end


    % now loop through each token
    tokenList = regexp(newLine, ' ');
    presentTokenStart = 1;
    foundFirstToken = 0;
    thisParm = 1;
    for i = 1:length(tokenList)+1
        if i == length(tokenList)+1
            token = newLine(presentTokenStart:end-1);
        else
            token = newLine(presentTokenStart:tokenList(i)-1);
            presentTokenStart = tokenList(i) + 1;
        end
        if (isempty(token))
            continue;
        end
        % check if its a double
        newDouble = str2double(token);
        % check if its missing
        if strcmp(token, 'missing')
            newDouble = missing;
        end
        % check if its assumed
        if strcmp(token, 'assumed')
            newDouble = assumed;
        end
        % check if its knownbad
        if strcmp(token, 'knownbad')
           newDouble = knownbad;
        end
        % check if its valid
        if isnan(newDouble) & strcmp(token, 'missing')==0 & strcmp(token, 'knownbad')==0 & strcmp(token, 'assumed')==0
            break;
        end
        % increment this2D if first
        if foundFirstToken == 0
            this2D = this2D + 1;
            foundFirstToken = 1;
        end
        records(this2D, thisParm, thisRecord) = newDouble;
        thisParm = thisParm + 1;
    end

end

end
