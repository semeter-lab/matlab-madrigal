function [] = globalIsprint(url, ...
    parms, ...
    output, ...
    user_fullname, ...
    user_email, ...
    user_affiliation, ...
    startTime, ...
    endTime, ...
    inst, ...
    format, ...
    filters, ...
    kindats, ...
    expName, ...
    fileDesc, ...
    excludeExpName, ...
    timeout)
% globalIsprint is a script to search through the entire Madrigal database
% for appropriate data to print in ascii to a file
%
%    Inputs:
%
%        url - url to homepage of site to be searched (Example:
%              'http://millstonehill.haystack.mit.edu/'
%
%        parms - a comma delimited string listing the desired Madrigal
%            parameters in mnemonic form.
%            (Example: 'year,month,day,hour,min,sec,gdalt,dte,te').
%            Ascii space-separated data will be returned in the same
%            order as given in this string. See
%            http://cedar.openmadrigal.org/parameterMetadata/
%            for all possible parameters.
%
%        output - the local file name to store the resulting ascii data, or
%                 local directory to store files (one for each Madrigal
%                 file) if format set. If a file name, then all data is
%                 stored in column-delimited ascii in one file.  If a
%                 directory, then one file created per Madrigal file read,
%                 and format of output files must be set via format arg.
%
%        user_fullname - the full user name (Example: 'Bill Rideout')
%
%        user email -  Example: 'brideout@haystack.mit.edu'
%
%        user_affiliation - Example: 'MIT'
%
%        startTime - a Matlab time to begin search at. Example:
%                    datenum('20-Jan-1998 00:00:00') Time in UT
%
%        endTime - a Matlab time to end search at. Example:
%                  datenum('21-Jan-1998 23:59:59') Time in UT
%
%        inst - instrument code (integer).  See
%            http://cedar.openmadrigal.org/instMetadata/
%            for this list. Examples: 30 for Millstone
%            Hill Incoherent Scatter Radar, 80 for Sondrestrom Incoherent
%            Scatter Radar
%
%    Optional inputs
%
%        format - either empty string (the default) is saving to a single file, or
%           'Hdf5', 'netCDF4', or 'ascii' if saving individual files to a
%           directory.
%
%        filters - is the optional filters requested in exactly the form given in isprint
%         command line (example = 'filter=gdalt,,500 filter=ti,500,1000')
%         See:  http://millstonehill.haystack.mit.edu/ug_commandLine.html for details
%
%        kindats - is an optional array of kindat (kinds of data) codes to accept.
%           The default is an empty array, which will accept all kindats.
%
%        expName - a case insensitive regular expression that matches the experiment
%           name.  Default is zero-length string, which matches all experiment names.
%           For example, *ipy* matches any name containing ipy, IPY, etc.
%
%        fileDesc - a case insensitive regular expression that matches the file description.
%           Default is zero-length string, which matches all file descriptions.
%
%        excludeExpName - a case insensitive regular expression that matches the experiment
%           name.  Experiment is rejected if match. Default is zero-length
%           string, and no experiments excluded.
%
%    Returns: Nothing.
%
%    Affects: Writes results to output file
%
%
%
%  Example: globalIsprint('http://millstonehill.haystack.mit.edu/', ...
%                         'year,month,day,hour,min,sec,gdalt,dte,te', ...
%                         './isprint.txt', ...
%                         'Bill Rideout', ...
%                         'brideout@haystack.mit.edu', ...
%                         'MIT', ...
%                         datenum('20-Jan-1998 00:00:00'), ...
%                         datenum('21-Jan-1998 23:59:59'), ...
%                         30);
%
%  $Id: globalIsprint.m 6811 2019-03-28 19:13:46Z brideout $
%
arguments
    url (1,1) string
    parms (1,1) string
    output (1,1) string
    user_fullname (1,1) string
    user_email (1,1) string
    user_affiliation (1,1) string
    startTime (1,1) datetime
    endTime (1,1) datetime
    inst (1,1) {mustBeInteger}
    format (1,1) string = ""
    filters (1,1) string = ""
    kindats (1,:) = []
    expName (1,1) string = ""
    fileDesc (1,1) string = ""
    excludeExpName (1,1) string = ""
    timeout (1,1) {mustBePositive} = 15.0
end


cgiurl = getMadrigalCgiUrl(url, timeout);

% verify valid format
switch lower(format)
    case ""
        assert(~isfolder(output), 'If no format, then output must be a file, not a directory')
    case {"hdf5", "netcdf4"}
        version = getVersion(cgiurl);
        items = strsplit(version, '.');
        majorRelease = str2double(char(items(1)));
        assert(majorRelease >= 3, "Hdf5 or netCDF4 format requires Madrigal site  3.0 or later")
        assert(isfolder(output), "If format set, then output %s must be a directory", output)
    case "ascii"
        assert(isfolder(output), "If format set, then output %s must be a directory", output)
    otherwise
    error('Unknown format: %s', format);
end

% handle the case when experiments extend outside time range
stVec = datevec(startTime);
etVec = datevec(endTime);
timeFiltStr1 = sprintf(' date1=%02i/%02i/%04i time1=%02i:%02i:%02i ', ...
    stVec(2), stVec(3), stVec(1), stVec(4), stVec(5), round(stVec(6)));
timeFiltStr2 = sprintf(' date2=%02i/%02i/%04i time2=%02i:%02i:%02i ', ...
    etVec(2), etVec(3), etVec(1), etVec(4), etVec(5), round(etVec(6)));

filters = [filters, timeFiltStr1, timeFiltStr2];

expArray = getExperimentsWeb(cgiurl, inst, startTime, endTime, 1);
if isempty(expArray)
    error('Madmatlab:NoExperimentsFound', 'No experiments found for these arguments')
end

if strlength(format) == 0
    fid = fopen(output, 'w');
end

% loop through each experiment
for i = 1:height(expArray)

    % expName filter, if any
    if strlength(expName) > 0
        result = regexpi(expArray(i,:).name, expName, 'once');
        if isempty(result)
            continue;
        end
    end

    % excludeExpName filter, if any
    if strlength(excludeExpName) > 0
        result = regexpi(expArray(i,:).name, excludeExpName, 'once');
        if ~isempty(result)
            continue
        end
    end

     % for each experiment, find all default files
     expFileArray = getExperimentFilesWeb(cgiurl, expArray(i,:).id, 2*timeout);
     for j = 1:height(expFileArray)
         if expFileArray(j,:).category ~= 1
             continue
         end

         % kindat filter
         if ~isempty(kindats)
             okay = 0;
             for k = 1:length(kindats)
                 if (expFileArray(j,:).kindat == kindats(k))
                     okay = 1;
                     break;
                 end
             end
             if (okay == 0)
                 continue;
             end
         end

         % fileDesc filter, if any
         if strlength(fileDesc) > 0
             result = regexpi(expFileArray(j,:).status, fileDesc, 'once');
             if isempty(result)
                 continue;
             end
         end

         disp("Working on file " + expFileArray(j,:).name);

         outputFile = getOutputFile(expFileArray(j,:).name, format, output);

         % run isprintWeb
         data = isprintWeb(cgiurl, expFileArray(j,:).name, parms, ...
                           user_fullname, user_email, user_affiliation, ...
                           filters, outputFile);
         if (data == -1)
             disp("Skipping " + expFileArray(j,:).name)
             continue
         end

         % this code needed only if not writing individual files
         if (strcmp(format, ''))
             dataLens = size(data);

             if (length(dataLens) < 3)
                 continue;
             end

             for i3 = 1:dataLens(3)
                 for i1 = 1:dataLens(1)
                     dataOkay = 1;
                     for i2 = 1:dataLens(2)
                         % skip time NaN
                         if ((i2 == 1) && (isnan(data(i1,i2,i3))))
                             dataOkay = 0;
                             break;
                         end
                         if (dataOkay == 1)
                             fprintf(fid, '%g ', data(i1,i2,i3));
                         end
                    end
                     % end of line
                     if (dataOkay == 1)
                         fprintf(fid, '\n ');
                     end
                 end
             end % writing this file

         end

     end % experiment file loop

end % experiment loop

if strlength(format) == 0
    fclose(fid);
end
end

function outputFile = getOutputFile(fullFilename, format, output)
% getOutputFile returns the outputFile that isprintWeb wants given:
%   fullFilename - full path to file on Madrigal server
%   format - either '', 'Hdf5', 'netCDF4', or 'ascii'
%   output - directory to put files in
if strlength(format) == 0
    outputFile = "";
    return
end
[~,name,~] = fileparts(fullFilename);
switch format
    case 'Hdf5', outputFile = fullfile(output, name + ".hdf5");
    case 'netCDF4', outputFile = fullfile(output, name + ".nc");
    otherwise, outputFile = fullfile(output, name + ".txt");
end
end
