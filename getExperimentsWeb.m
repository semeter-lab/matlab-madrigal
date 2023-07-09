function expArray = getExperimentsWeb(cgiurl, instCodeArray, starttime, endtime, localFlag, timeout)
%  getExperimentsWeb  	returns an array of experiment structs given input filter arguments from a remote Madrigal server.
%
%  Inputs:
%
%      1. cgiurl (string) to Madrigal site cgi directory
%        (Example: 'http://madrigal.haystack.mit.edu/cgi-bin/madrigal/')
%         Note that method getMadrigalCgiUrl converts homepage url into cgiurl.
%
%      2. instCodeArray - a 1 X N array of ints containing selected instrument codes.  Special value of 0 selects all instruments.
%
%      3. starttime - Matlab datenum double (must be UTC)
%
%      4. endtime - Matlab datenum double (must be UTC)
%
%      5. localFlag - 1 if local experiments only, 0 if all experiments
%
%   Returns a startime sorted array of Experiment struct (May be empty):
%
%   experiment.id (int) Example: 10000111
%   experiment.url (string) Example: 'http://madrigal.haystack.mit.edu/cgi-bin/madtoc/1997/mlh/03dec97'
%      Deprecated url used only in metadata. To see real url, use realUrl
%      field described below
%   experiment.name (string) Example: 'Wide Latitude Substorm Study'
%   experiment.siteid (int) Example: 1
%   experiment.sitename (string) Example: 'Millstone Hill Observatory'
%   experiment.instcode (int) Code of instrument. Example: 30
%   experiment.instname (string) Instrument name. Example: 'Millstone Hill Incoherent Scatter Radar'
%   experiment.starttime (double) Matlab datenum of experiment start
%   experiment.endtime (double) Matlab datenum of experiment end
%   experiment.isLocal (int) 1 if local, 0 if not
%   experiment.madrigalUrl (string) - home url of Madrigal site with this
%       experiment. Example 'http://millstonehill.haystack.mit.edu'
%   experiment.PI - experiment principal investigator.  May be unknown for
%       Madrigal 2.5 and earlier sites.
%   experiment.PIEmail - PI email. May be unknown for Madrigal 2.6 or
%       earlier.
%   realUrl - real url to experiment valid for web browser
%
%  Raises error if unable to return experiment array
%
%  Example: expArray = getExperimentsWeb('http://madrigal.haystack.mit.edu/cgi-bin/madrigal/', ...
%                                         30, datenum('01/01/1998'), datenum('12/31/1998'), 1);
%
%   Note that if the returned
%   experiment is not local, the experiment.id will be -1.  This means that you
%   will need to call getExperimentsWeb a second time with the cgiurl of the
%   non-local experiment (getCgiurlForExperiment(experiment.madrigalUrl)).  This is because
%   while Madrigal sites share metadata about experiments, the real experiment ids are only
%   known by the individual Madrigal sites.  See testMadmatlab.m
%   for an example of this.
arguments
    cgiurl (1,1) string
    instCodeArray (1,:) {mustBeInteger}
    starttime (1,1) datetime
    endtime (1,1) datetime
    localFlag (1,1) {mustBeInteger}
    timeout (1,1) = 15.0
end

% we first need to call getMetadata to create a dictionary of siteIds and
% Urls - form will be cell array where each cell is a cell array of two
% items, the siteId and the main site url
siteDict = {};
siteUrl = cgiurl + "/getMetadata?fileType=5";
% now get that url
disp(siteUrl)
result = webread(siteUrl, weboptions('Timeout',timeout, 'ContentType', 'text'));

% surpress matlab warning about multibyte Characters
%warning off REGEXP:multibyteCharacters

% parse site result
lines = split(string(result), newline);

%% loop through each line
for i = 1:length(lines)
    if strlength(lines(i)) < 10
        continue
    end
    line = split(lines(i), ",");

    id = str2double(line(1));
    % name = dat(2);
    url = line(3);
    url2 = line(4);

    % append new data
    siteDict = [ siteDict {id, "http://" + url + "/" + url2 }];
end


% build the complete cgi url
cgiurl = cgiurl + "getExperimentsService.py?";


% append --code options
for i = 1:length(instCodeArray)
    cgiurl = cgiurl + sprintf('code=%i&', instCodeArray(i));
end

% append start / end time
cgiurl = cgiurl + sprintf('startyear=%i&startmonth=%i&startday=%i&starthour=%i&startmin=%i&startsec=%i&endyear=%i&endmonth=%i&endday=%i&endhour=%i&endmin=%i&endsec=%i&', ...
    starttime.Year, starttime.Month, starttime.Day, ...
    starttime.Hour, starttime.Minute, round(starttime.Second), ...
    endtime.Year, endtime.Month, endtime.Day,...
    endtime.Hour, endtime.Minute, round(endtime.Second));

% append localFlag
cgiurl = cgiurl + "local=";
if localFlag == 0
    cgiurl = cgiurl + "0";
else
    cgiurl = cgiurl + "1";
end

% make sure any + replaced by %2B
cgiurl = strrep(cgiurl, "+", "%2B");

% now get that url
disp(cgiurl)
result = webread(cgiurl);

% look for errors - if html returned, error occurred
if strlength(result) == 0 || contains(result, "</html>")
    error('madmatlab:scriptError', "Unable to run cgi script getExperimentsWeb using cgiurl: %s ", cgiurl)
end

%% parse result
% init array to return
expArray = [];

lines = split(string(result), newline);
% loop through each line
for i = 1:length(lines)
    if strlength(lines(i)) < 10
        continue
    end
    line = split(lines(i), ",");
    % id
    newExperiment.id = str2double(line(1));
    % url
    newExperiment.url = line(2);
    % name
    newExperiment.name = line(3);
    % siteid
    newExperiment.siteid = str2double(line(4));
    % site name
    newExperiment.sitename = line(5);
    % instcode
    newExperiment.instcode = str2double(line(6));
    % inst name
    newExperiment.instname = line(7);
    % get starttime
    newExperiment.starttime = datetime(str2double(line(8)), str2double(line(9)), str2double(line(10)), str2double(line(11)), str2double(line(12)), str2double(line(13)));
    % get endtime
    newExperiment.endtime = datetime(str2double(line(14)), str2double(line(15)), str2double(line(16)), str2double(line(17)), str2double(line(18)), str2double(line(19)));
    % finally, isLocal - may or may not be last
    newExperiment.isLocal = str2double(line(20));

    if (newExperiment.isLocal == 0)
        newExperiment.id = -1;
    end

    newExperiment.madrigalUrl = 'unknown';
    for i = 1:2:length(siteDict)+1
        if siteDict{i} == newExperiment.siteid
            newExperiment.madrigalUrl = siteDict{i+1};
            break
        end
    end

    if length(line) > 20
        newExperiment.PI = line(21);
    else
        newExperiment.PI = 'Unknown';
    end

    if length(line) >= 21
        newExperiment.PIEmail = line(22);
    else
        newExperiment.PIEmail = 'Unknown';
    end

    % realUrl
    realUrl = newExperiment.url;
    realUrl = strrep(realUrl, "/madtoc/", "/madExperiment.cgi?exp=");
    title = strrep(newExperiment.name, " ", "+");
    newExperiment.realUrl = realUrl + "&displayLevel=0&expTitle=" + title;

    % append new experiments
    expArray = [expArray newExperiment];

% now sort the array based on
% http://blogs.mathworks.com/pick/2010/09/17/sorting-structure-arrays-based-on-fields/
% expArrayFields = fieldnames(expArray);
% expArrayCell = struct2cell(expArray);
% sz = size(expArrayCell);
% expArrayCell = reshape(expArrayCell, sz(1), []);
% expArrayCell = expArrayCell';
% expArrayCell = sortrows(expArrayCell, 8);
% expArrayCell = reshape(expArrayCell', sz);
% expArray = cell2struct(expArrayCell, expArrayFields, 1);

end
