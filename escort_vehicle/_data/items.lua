return {
    ['stretcher'] = {
        label = 'ストレッチャー',
        weight = 5000,
        stack = false,
        close = true,
        description = '救急搬送用ストレッチャー。使用して展開できます。',
        client = {
            export = 'escort_vehicle.useStretcher'  -- 【重要】リソース名と完全一致
        }
    },
}
