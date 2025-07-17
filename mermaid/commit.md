# Commit Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press c for commit| C[Commit Working Copy]
    B -->|Press C for commit menu| D[Commit Menu Options]
    B -->|leader+a action menu| E[Action Menu]
    
    %% Commit Working Copy (simple)
    C --> F[commit_working_copy]
    F --> G[Build jj commit command]
    G --> H[jj commit]
    
    %% Commit Menu Options
    D --> I[show_commit_menu]
    I --> J{Select Option}
    
    J -->|c| K[Commit working copy]
    J -->|m| L[Commit with message]
    J -->|i| M[Interactive commit]
    J -->|a| N[Commit all changes]
    J -->|s| O[Show working copy status]
    
    %% Commit with Message
    L --> P[Prompt for commit message]
    P --> Q{Message Provided?}
    Q -->|No| R[Cancel operation]
    Q -->|Yes| S[commit_working_copy with message]
    S --> T[Build jj commit command]
    T --> U[jj commit -m message]
    
    %% Interactive Commit
    M --> V[commit_working_copy interactive]
    V --> W[Build jj commit command]
    W --> X[jj commit --interactive]
    
    %% Commit All Changes
    N --> Y[commit_working_copy all]
    Y --> Z[Build jj commit command]
    Z --> AA[jj commit --all]
    
    %% Show Working Copy Status
    O --> BB[Get working copy status]
    BB --> CC[show_status]
    CC --> DD[Display status buffer]
    
    %% Simple Commit
    K --> EE[commit_working_copy]
    EE --> FF[Build jj commit command]
    FF --> GG[jj commit]
    
    %% Action Menu Flow
    E --> HH{Menu Selection}
    HH -->|Global Action| II[Commit working copy c]
    II --> F
    
    %% Common Execution Path
    H --> JJ[commands.execute_with_immutable_prompt]
    U --> JJ
    X --> JJ
    AA --> JJ
    GG --> JJ
    
    JJ --> KK[Execute jj command]
    KK --> LL{Success?}
    
    LL -->|Yes| MM[Parse commit result]
    LL -->|No| NN[Show error message]
    
    %% Success Path
    MM --> OO[Extract new commit ID]
    OO --> PP[Show success notification]
    PP --> QQ[Show commit summary]
    QQ --> RR[Refresh log display]
    RR --> SS[Update commit graph]
    SS --> TT[Highlight new commit]
    
    %% Interactive Commit Handling
    X --> UU{Interactive Mode?}
    UU -->|Yes| VV[Open interactive terminal]
    UU -->|No| KK
    
    VV --> WW[User selects changes]
    WW --> XX[Terminal completion]
    XX --> YY[Return to plugin]
    YY --> KK
    
    %% Message Input Dialog
    P --> ZZ[Configure input dialog]
    ZZ --> AAA[Set dialog title]
    AAA --> BBB[Set placeholder text]
    BBB --> CCC[Show current status]
    CCC --> DDD[vim.ui.input prompt]
    
    %% Working Copy Status Check
    F --> EEE[Check working copy status]
    EEE --> FFF{Has Changes?}
    FFF -->|No| GGG[Show info - no changes to commit]
    FFF -->|Yes| G
    
    EE --> HHH[Check working copy status]
    HHH --> III{Has Changes?}
    III -->|No| GGG
    III -->|Yes| FF
    
    %% Validation
    S --> JJJ[Validate commit message]
    JJJ --> KKK{Message Valid?}
    KKK -->|No| LLL[Show error - invalid message]
    KKK -->|Yes| T
    
    %% Error Handling
    NN --> MMM[Return to previous state]
    R --> MMM
    GGG --> MMM
    LLL --> MMM
    
    %% Commit Result Processing
    MM --> NNN[Parse commit output]
    NNN --> OOO[Extract commit metadata]
    OOO --> PPP[Get commit description]
    PPP --> QQQ[Get commit timestamp]
    QQQ --> RRR[Get parent information]
    
    %% Success Feedback
    QQ --> SSS[Show commit details]
    SSS --> TTT[Display commit ID]
    TTT --> UUU[Show commit message]
    UUU --> VVV[Show files changed]
    VVV --> WWW[Show insertions/deletions]
    
    %% Status Display Integration
    DD --> XXX[Show working copy files]
    XXX --> YYY[Show staged changes]
    YYY --> ZZZ[Show untracked files]
    ZZZ --> AAAA[Show conflicts]
    
    %% Menu Selection Handling
    I --> BBBB[handle_commit_menu_selection]
    BBBB --> CCCC[Process selected option]
    CCCC --> DDDD[Execute appropriate action]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef interactive fill:#e1f5fe
    classDef validation fill:#fff3e0
    
    class A,B,C,D,E userAction
    class I,J,P,Q,ZZ,AAA,BBB,CCC,DDD,BBBB,CCCC,DDDD menuAction
    class F,S,V,Y,EE,G,T,W,Z,FF,JJ,KK,MM,OO execution
    class H,U,X,AA,GG command
    class PP,QQ,RR,SS,TT,SSS,TTT,UUU,VVV,WWW success
    class NN,MMM,GGG,LLL error
    class VV,WW,XX,YY,UU interactive
    class EEE,FFF,HHH,III,JJJ,KKK validation
```

## Key Menu Options

- **c**: Commit working copy (simple commit)
- **m**: Commit with message (prompt for commit message)
- **i**: Interactive commit (select changes interactively)
- **a**: Commit all changes (--all flag)
- **s**: Show working copy status before committing

## Command Variations

- **Simple**: `jj commit` - commits working copy changes
- **With Message**: `jj commit -m "message"` - commits with specified message
- **Interactive**: `jj commit --interactive` - opens interactive selection
- **All Changes**: `jj commit --all` - commits all changes including untracked

## Interactive Features

- **Message Input**: Native vim input dialog for commit messages
- **Interactive Selection**: Terminal-based file selection for staging
- **Status Preview**: Shows working copy status before committing
- **Validation**: Ensures there are changes to commit

## Commit Process

1. **Status Check**: Verifies working copy has changes
2. **Message Input**: Prompts for commit message (if needed)
3. **Validation**: Ensures message is valid
4. **Execution**: Executes appropriate jj commit command
5. **Feedback**: Shows commit result and updates display

## Success Feedback

After successful commit:
- **Commit Details**: Shows new commit ID and message
- **File Summary**: Lists changed files and statistics
- **Graph Update**: Refreshes log display with new commit
- **Highlighting**: Highlights the new commit in the log

## Working Copy Status

The status check shows:
- **Modified Files**: Files with changes
- **Staged Changes**: Changes ready for commit
- **Untracked Files**: New files not in version control
- **Conflicts**: Any merge conflicts present

## File Locations

- **Core**: `lua/jj-nvim/jj/commit.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:568-571`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua` (global actions)
- **Keybindings**: `c` for commit, `C` for commit menu