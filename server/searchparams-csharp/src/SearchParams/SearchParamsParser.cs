// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

namespace SearchParams;

// Stub host for the sidecar wire protocol. Full Go-matching parse is PROG-64.
public static class SearchParamsParser
{
    public static SearchParamsResult[] Parse(string text, int timeZoneOffset)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return [];
        }

        return
        [
            new SearchParamsResult
            {
                Terms = text.Trim(),
                TimeZoneOffset = timeZoneOffset,
            },
        ];
    }
}
