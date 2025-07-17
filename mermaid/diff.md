# Diff Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press d on commit| C[Single Commit Diff]
    B -->|leader+a action menu| D[Action Menu]
    
    %% Single Commit Diff Flow
    C --> E[Get commit under cursor]
    E --> F{Valid Commit?}
    F -->|No| G[Show error - no commit selected]
    F -->|Yes| H[show_diff with default format]
    
    %% Action Menu Flow
    D --> I{Menu Selection}
    I -->|Single Selection| J[Show diff d]
    J --> E
    
    %% Diff Format Selection
    H --> K{Diff Format}
    K -->|Default| L[Git format diff]
    K -->|Stat| M[Summary statistics]
    K -->|Color Words| N[Word-level diff]
    K -->|Name Only| O[File names only]
    
    %% Git Format Diff
    L --> P[show_diff git format]
    P --> Q[Build jj diff command]
    Q --> R[jj diff --git change_id]
    
    %% Summary Statistics
    M --> S[show_diff_summary]
    S --> T[Build jj diff command]
    T --> U[jj diff --stat change_id]
    
    %% Color Words Diff
    N --> V[show_diff color-words]
    V --> W[Build jj diff command]
    W --> X[jj diff --color-words change_id]
    
    %% Name Only Diff
    O --> Y[show_diff name-only]
    Y --> Z[Build jj diff command]
    Z --> AA[jj diff --name-only change_id]
    
    %% Common Execution Path
    R --> BB[commands.execute_with_immutable_prompt]
    U --> BB
    X --> BB
    AA --> BB
    
    BB --> CC[Execute jj command]
    CC --> DD{Success?}
    
    DD -->|Yes| EE[Create diff buffer]
    DD -->|No| FF[Show error message]
    
    %% Success Path - Buffer Creation
    EE --> GG[Set buffer options]
    GG --> HH[Apply syntax highlighting]
    HH --> II{Diff Format}
    
    II -->|Git| JJ[Apply git diff syntax]
    II -->|Stat| KK[Apply stat syntax]
    II -->|Color Words| LL[Apply color-words syntax]
    II -->|Name Only| MM[Apply name-only syntax]
    
    JJ --> NN[Display diff buffer]
    KK --> NN
    LL --> NN
    MM --> NN
    
    NN --> OO[Set buffer keymaps]
    OO --> PP[Show diff window]
    PP --> QQ[Set window options]
    QQ --> RR[Focus diff window]
    
    %% Buffer Configuration
    GG --> SS[Set buffer properties]
    SS --> TT[buftype=nofile]
    TT --> UU[modifiable=false]
    UU --> VV[filetype=diff]
    
    %% Window Configuration
    QQ --> WW[Set window properties]
    WW --> XX[Split window]
    XX --> YY[Resize appropriately]
    YY --> ZZ[Set buffer name]
    
    %% Error Handling
    FF --> AAA[Return to previous state]
    G --> AAA
    
    %% Keymaps in Diff Buffer
    OO --> BBB[Set buffer keymaps]
    BBB --> CCC[q - close diff]
    CCC --> DDD[Enter - go to file]
    DDD --> EEE[Other navigation keys]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef validation fill:#fff3e0
    classDef execution fill:#e8f5e8
    classDef buffer fill:#f3e5f5
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D userAction
    class E,F,H,K validation
    class P,S,V,Y,Q,T,W,Z,BB,CC execution
    class EE,GG,HH,II,JJ,KK,LL,MM,NN,OO,PP,QQ,RR,SS,TT,UU,VV,WW,XX,YY,ZZ,BBB,CCC,DDD,EEE buffer
    class success success
    class FF,G,AAA error
```

## Key Features

- **Multiple Diff Formats**: Git, stat, color-words, name-only
- **Syntax Highlighting**: Format-specific highlighting in diff buffer
- **Buffer Management**: Creates dedicated diff buffer with proper configuration
- **Navigation**: Keymaps for easy navigation within diff buffer

## Diff Formats

- **Git Format**: `jj diff --git` - Standard git-style diff
- **Stat Format**: `jj diff --stat` - Summary statistics (files changed, insertions, deletions)
- **Color Words**: `jj diff --color-words` - Word-level diff highlighting
- **Name Only**: `jj diff --name-only` - Just file names that changed

## Buffer Features

- **Read-only**: Buffer is not modifiable
- **Syntax Highlighting**: Appropriate syntax for each diff format
- **Keymaps**: `q` to close, `Enter` to go to file, navigation keys
- **Window Management**: Split window with appropriate sizing

## File Locations

- **Core**: `lua/jj-nvim/jj/diff.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:531-533`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:102-107`
- **Keybinding**: `d` key for diff operation