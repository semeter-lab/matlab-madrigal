function expFileArray = getExperimentFilesWeb(cgiurl, experimentId, timeout)
%  getExperimentFilesWeb  	returns an array of experiment file structs given experiment id from a remote Madrigal server.
%
%  Note that it is assumed that experiment is local to cgiurl.  If not,
%  empty list will be returned. Use getCgiurlForExperiment to get the correct
%  cgiurl for any given experiment struct.
%
%  Inputs:
%
%      1. cgiurl (string) to Madrigal site cgi directory that has that
%      experiment.
%        (Example: 'http://madrigal.haystack.mit.edu/cgi-bin/madrigal/')
%         Note that method getMadrigalCgiUrl converts homepage url into cgiurl.
%
%      2. experiment id (int) as returned by getExperiments or
%         getExperimentsWeb
%
%   Return array of Experiment File struct (May be empty):
%
%   file.name (string) Example '/opt/mdarigal/blah/mlh980120g.001'
%   file.kindat (int) Kindat code.  Example: 3001
%   file.kindatdesc (string) Kindat description: Example 'Basic Derived Parameters'
%   file.category (int) (1=default, 2=variant, 3=history, 4=real-time)
%   file.status (string)('preliminary', 'final', or any other description)
%   file.permission (int)  0 for public, 1 for private
%   file.doi (string) - citable doi for file ('None' if not available)
%
%  Raises error if unable to return experiment file array
%
%  Example: expFileArray =
%  getExperimentFilesWeb('http://madrigal.haystack.mit.edu/cgi-bin/madrigal/', 10001686);
arguments
    cgiurl (1,1) string
    experimentId (1,1) {mustBeInteger}
    timeout (1,1) {mustBePositive} = 15.0
end

if experimentId == -1
    error('madmatlab:badArguments', 'Invalid experiment id.  This is usually caused by calling getExperimentsWeb for a non-local experiment.  You need to make a second call to getExperimentsWeb with the cgiurl of the non-local experiment (getCgiurlForExperiment(experiment.url))')
end

% build the complete cgi url
if endsWith(cgiurl, "/")
    cgiurl = cgiurl + "getExperimentFilesService.py?";
else
    cgiurl = cgiurl + "/getExperimentFilesService.py?";
end


% append id
cgiurl = cgiurl + sprintf("id=%s", int2str(experimentId));

% make sure any + replaced by %2B
cgiurl = strrep(cgiurl, "+", "%2B");

% now get that url
disp(cgiurl)
result = webread(cgiurl, weboptions(Timeout=timeout, ContentType='text'));

% look for errors - if html returned, error occurred
if contains(result, "</html>")
    error('madmatlab:scriptError', 'Unable to run cgi script getExperimentFilesWeb using cgiurl: %s ', cgiurl)
end

% surpress matlab warning about multibyte Characters
% warning off REGEXP:multibyteCharacters

% parse result

% init array to return
expFileArray = struct();

lines = split(string(result), newline);
% loop through each line
for i = 1:length(lines)
    if strlength(lines(i)) < 10
        continue
    end

    line = split(lines(i), ",");
    % name
    newExperimentFile.name = strtrim(line(1));
    % kindat
    newExperimentFile.kindat = str2double(line(2));
    % kindatdesc
    newExperimentFile.kindatdesc = line(3);
    % category
    newExperimentFile.category = str2double(line(4));
    % status
    newExperimentFile.status = line(5);
    % permission
    newExperimentFile.permission = str2double(line(6));
    % doi
    if length(commaMarks) >= 6
        newExperimentFile.doi = line(7);
    else
        newExperimentFile.doi = 'None';
    end

    % append new experiments
    expFileArray(i) = newExperimentFile;
end

end
